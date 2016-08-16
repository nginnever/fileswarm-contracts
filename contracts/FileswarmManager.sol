contract FileswarmManager {
  address public owner;
  address[] public files;
  
  struct IPFS {
    string hash1;
    string hash2;
  }
  
  mapping (address => IPFS) public seeders;

  modifier isSeeding(address x)
  {
    if(File(x).getSeederAddr(msg.sender) != 0x0) throw;
    _
  }

  function FileswarmManager() {
    owner = msg.sender;
  }
  
  function getFilesCount() public constant returns(uint) {
    return files.length;
  }
  
  function getFile(uint i) public constant returns(address) {
    return files[i];
  }
  
  function createFile() returns(bool res) {
    address f = new File(msg.sender, msg.value);
    files.push(f);
    return true;
  }
  
  function seed(address ifile, string _hash1, string _hash2) isSeeding(ifile) returns(bool res) {
    IPFS entry = seeders[msg.sender];
    // this hash logs all of the chunks a seeder is seeding for client side ops
    entry.hash1 = _hash1;
    entry.hash2 = _hash2;
    File(ifile).addSeeder(msg.sender);
    return true;
  }
  
  function unseed(address ifile, string _hash1, string _hash2) returns(bool res) {
    if(msg.sender != ifile) throw;
    IPFS entry = seeders[msg.sender];
    entry.hash1 = _hash1;
    entry.hash2 = _hash2;
    File(ifile).removeSeeder(msg.sender);
  }
}

contract File {
    
  uint public test = 0;
  
  address public owner;
  uint public balance;
  uint public blockNum;
  uint public time;
  uint public round;
  uint public numChunks;
  uint public confirmedCount;
  // TODO kick seeders off a chunk after missing x rounds
  uint public allowedMissedRounds;
  
  mapping (uint => address) public confirmed;
  uint amt = 14;
  
  struct IPFS {
    uint chunkNum;
    address seeder;
    uint challengeNum;
  }
  
  struct Chunk {
    string hash1;
    string hash2;
    string challenge1;
    string challenge2;
    uint roundNum;
    uint challenges;
    uint seedersNum;
    address rewardQue;
  }
  
  mapping (uint => Chunk) public chunks;
  mapping (address => IPFS) public seeders;
  
  modifier isTime()
  {
    if (now < time + 1 minutes) throw;
    _
  }
  
  modifier isChallengeable(address challenger, uint _cNum)
  {
    if (seeders[challenger].seeder == 0x0) throw;
    if (seeders[challenger].chunkNum != _cNum) throw;
    if (chunks[_cNum].roundNum == seeders[challenger].challengeNum && round == chunks[_cNum].roundNum) throw;
    _
  }
  
  function File(address _owner, uint _balance) {
    owner = _owner;
    balance = _balance;
    blockNum = block.number;
    time = now;
    round = 1;
  }
  
  function setNumChunks(uint num) {
    numChunks = num;
  }
  
  function addChunk(uint index, string _hash1, string _hash2) {
    Chunk memory entry;
    entry.hash1 = _hash1;
    entry.hash2 = _hash2;
    entry.roundNum = 1;
    chunks[index] = entry;
  }
  
  // Since sol can't return structs externally,
  // we have a getter for each member.
  //function getChunk(uint i) internal constant returns(IPFS) {
  //  IPFS chunk = chunks[i];
  //  return chunk;
  //}
  
  function getSeederAddr(address a) public constant returns(address) {
    return seeders[a].seeder;
  }
  
  function setNewChallenge() isTime() public {
    time = now;
    blockNum = block.number;
    round++;
    pay();
  }
  
  function addSeeder(address s) {
    // Throw if the sender is already seeding a chunk of this file
    if(seeders[s].seeder != 0x0) throw;
    // Throw if the chunk has more than 4 seeders already
    if(chunks[blockNum % numChunks].seedersNum > 4) throw;
    seeders[s].seeder = s;
    seeders[s].chunkNum = blockNum % numChunks;
    chunks[seeders[s].chunkNum].seedersNum++;
    //seeders[s].challengeNum = 0;
  }
  
  function removeSeeder(address s) {
    seeders[s].seeder = 0x0;
    seeders[s].chunkNum = 0;
    seeders[s].challengeNum = 0;
  }
  
  function challenge(uint _chunkNum, string _hash1, string _hash2) isChallengeable(msg.sender, _chunkNum){
    validate(_chunkNum, _hash1, _hash2 );
  }
  
  function validate(uint _chunkNum, string _hash1, string _hash2) internal {
    if(chunks[_chunkNum].roundNum != round) {
      chunks[_chunkNum].roundNum = round;
      chunks[_chunkNum].challenges = 0;
    }
    
    if(chunks[_chunkNum].challenges == 0) {
      chunks[_chunkNum].challenge1 = _hash1;
      chunks[_chunkNum].challenge2 = _hash2;
      chunks[_chunkNum].challenges++;
      chunks[_chunkNum].rewardQue = msg.sender;
      seeders[msg.sender].challengeNum = chunks[_chunkNum].roundNum;
      return;
    }
    
    // TODO what happens if first challenge is incorrect
    // TODO what happens if someone reads this value then responds
    // without actually computing the hash from stored data
    if(chunks[_chunkNum].challenges == 1) {
      if(stringsEqual(chunks[_chunkNum].challenge1, _hash1)) {
        chunks[_chunkNum].challenges++;
        confirmed[confirmedCount + 1] = chunks[_chunkNum].rewardQue;
        confirmed[confirmedCount + 2] = msg.sender;
        confirmedCount = confirmedCount + 2;
        chunks[_chunkNum].rewardQue = 0x0;
        seeders[msg.sender].challengeNum = chunks[_chunkNum].roundNum;
      }
      return;
    }
    
    if(chunks[_chunkNum].challenges == 2) {
      if(stringsEqual(chunks[_chunkNum].challenge1, _hash1)) {
        chunks[_chunkNum].challenges++;
        confirmed[confirmedCount + 1] = msg.sender;
        confirmedCount = confirmedCount + 1;
        seeders[msg.sender].challengeNum = chunks[_chunkNum].roundNum;
      }
      return;
    }
  }
  
  function pay() internal{
    // TODO fix payments  
    for(uint i = 0; i < confirmedCount + 1; i++) {
      // BUG this will deduct 1 too many times
      balance = balance - amt;
      confirmed[i].send(amt);
      delete confirmed[i];
    }
    confirmedCount = 0;
  }
  
  function stringsEqual(string storage _a, string memory _b) internal returns (bool) {
  bytes storage a = bytes(_a);
  bytes memory b = bytes(_b);
  if (a.length != b.length)
    return false;
  // @todo unroll this loop
  for (uint i = 0; i < a.length; i ++)
    if (a[i] != b[i])
      return false;
  return true;
  }
}
