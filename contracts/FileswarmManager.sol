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
  uint public challengeNum;
  uint public numChunks;
  bool public setTime;
  address[] public confirmed;
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
    uint roundChallengeNum;
    address rewardQue;
    mapping (address => bool) roundChallengers;
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
    if (chunks[_cNum].roundNum == seeders[challenger].challengeNum) throw;
    _
  }
  
  function File(address _owner, uint _balance) {
    owner = _owner;
    balance = _balance;
    blockNum = block.number;
    setTime = true;
    time = now;
    challengeNum = 0;
  }
  
  function setNumChunks(uint num) {
    numChunks = num;
  }
  
  function addChunk(uint index, string _hash1, string _hash2) {
    Chunk memory entry;
    entry.hash1 = _hash1;
    entry.hash2 = _hash2;
    chunks[index] = entry;
  }
  
  // Since sol can't return structs externally,
  // we have a getter for each member.
  //function getChunk(uint i) internal constant returns(IPFS) {
  //  IPFS chunk = chunks[i];
  //  return chunk;
  //}
  
  function getChunk(uint i) public returns (string _hash1, string _hash2) {
    Chunk temp = chunks[i];
    _hash1 = temp.hash1;
    _hash2 = temp.hash2;
  }
  
  function getConfirmedCount() public constant returns(uint) {
    return confirmed.length;
  }
  
  function getSeederAddr(address a) public constant returns(address) {
    return seeders[a].seeder;
  }
  
  function setNewChallenge() isTime() {
    time = now;
    blockNum = block.number;
    challengeNum++;
    pay();
  }
  
  function addSeeder(address s) {
    seeders[s].seeder = s;
    seeders[s].chunkNum = blockNum % numChunks;
  }
  
  function removeSeeder(address s) {
    seeders[s].seeder = 0x0;
    seeders[s].chunkNum = 0;
  }
  
  function challenge(uint _chunkNum, string _hash1, string _hash2) isChallengeable(msg.sender, _chunkNum){
    if(validate(_chunkNum, _hash1, _hash2 )) {
      confirmed.push(msg.sender);
      seeders[msg.sender].challengeNum = chunks[_chunkNum].roundNum;
    }
  }
  
  function validate(uint _chunkNum, string _hash1, string _hash2) internal returns(bool) {
    if(chunks[_chunkNum].roundNum != challengeNum) {
      chunks[_chunkNum].roundNum = challengeNum;
    }
    
    if(chunks[_chunkNum].roundChallengeNum == 0) {
      chunks[_chunkNum].challenge1 = _hash1;
      chunks[_chunkNum].challenge2 = _hash2;
      chunks[_chunkNum].roundChallengeNum++;
      chunks[_chunkNum].rewardQue = msg.sender;
      seeders[msg.sender].challengeNum = chunks[_chunkNum].roundNum;
      return false;
    }
    
    if(chunks[_chunkNum].roundChallengeNum == 1) {
      if(stringsEqual(chunks[_chunkNum].challenge1, _hash1)) {
        chunks[_chunkNum].roundChallengeNum = 2;
        confirmed.push(chunks[_chunkNum].rewardQue);
        return true;
      }
    }
    
    if(chunks[_chunkNum].roundChallengeNum == 2) {
      if(stringsEqual(chunks[_chunkNum].challenge1, _hash1)) {
        confirmed.push(chunks[_chunkNum].rewardQue);
        return true;
      }  
    }
  }
  
  function pay() {
    for(uint i = 0; i < confirmed.length; i++) {
      test++;
      balance - amt;
      bool tests = confirmed[i].send(amt);
      delete confirmed[i];
    }
    confirmed.length = 0;
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
