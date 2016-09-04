contract FileswarmManager {
  address public owner;
  uint public filecount;
  address[] public files;

  struct Files {
    bytes hash;
  }
  
  struct Seed {
    string hash1;
    string hash2;
  }
  
  mapping (address => Seed) public seeders;
  mapping (address => Files) public userFiles;

  modifier isSeeding(address x)
  {
    if(File(x).getSeederAddr(msg.sender) != 0x0) throw;
    _
  }

  function FileswarmManager() {
    owner = msg.sender;
  }
  
  function createFile(bytes _hash) returns(bool res) {
    address f = new File(msg.sender, msg.value, _hash);
    Files newFile = userFiles[msg.sender];
    newFile.hash = _hash;
    filecount++;
    files.push(f);
    return true;
  }
  
  function seed(address ifile, string _hash1, string _hash2) isSeeding(ifile) returns(bool res) {
    Seed entry = seeders[msg.sender];
    // this hash logs all of the chunks a seeder is seeding for client side ops
    entry.hash1 = _hash1;
    entry.hash2 = _hash2;
    File(ifile).addSeeder(msg.sender);
    return true;
  }
}

contract File {
  address public owner;
  uint public balance;
  uint public blockNum;
  uint public time;
  uint public rand;
  uint public round;
  uint public numChunks;
  uint public confirmedCount;
  uint public numSeeders;
  // TODO kick seeders off a chunk after missing x rounds
  uint public allowedMissedRounds;
  
  // IPFS protobuf encodings
  bytes merkledagprefix = hex"0a";
  bytes unixfsprefix = hex"080212";
  bytes postfix = hex"18";
  bytes32 public sha;
  
  address[] public rewarded;
  uint amt = 14;
  
  struct Seeder {
    uint amountRewarded;
    address seeder;
    uint challengeNum;
    bool rewarded;
  }
  
  bytes fileHash;
  bytes32[] public chunks;
  bytes32 public challengeHash;
  //mapping (uint => Chunk) public chunks;
  mapping (address => Seeder) public seeders;
  
  modifier isTime()
  {
    if (now < time + 1 minutes) throw;
    _
  }
  
  modifier isChallengeable(address challenger)
  {
     if (seeders[challenger].seeder != challenger || seeders[challenger].challengeNum < round) throw;
    _
  }
  
  function File(address _owner, uint _balance, bytes _hash) {
    owner = _owner;
    balance = _balance;
    blockNum = block.number;
    time = now;
    round = 1;
    fileHash = _hash;
  }
  
  function setNumChunks(uint num) {
    numChunks = num;
  }
  
  function addChunk(bytes32 _hash) {
    chunks.push(_hash);
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
    rand = blockNum % chunks.length;
    challengeHash = chunks[rand];
    confirmedCount = 0;
  }
  
  function addSeeder(address s) {
    // Throw if the sender is already seeding a chunk of this file
    if(seeders[s].seeder != 0x0) throw;
    // Throw if the file has more than 4 seeders already
    if(numSeeders > 4) throw;
    seeders[s].seeder = s;
    seeders[s].rewarded = false;
    seeders[s].amountRewarded = 0;
    seeders[s].challengeNum = 0;
  }
  
  function challenge(string chunk) isChallengeable(msg.sender){
    if(IPFSvalidate(chunk)) {
      msg.sender.send(amt);
      balance = balance - amt;
      rewarded.push(msg.sender);
      confirmedCount++;
      seeders[msg.sender].challengeNum == round;
    }
  }
  
  function IPFSvalidate(string chunk) internal returns(bool) {
    bytes memory content = bytes(chunk);
    bytes memory len = to_binary(content.length);
    // 6 + content byte length
    bytes memory messagelen = to_binary(6 + content.length);
    //return message;
    sha = sha256(merkledagprefix, messagelen, unixfsprefix, len, content, postfix, len);
    if (sha == challengeHash) {
      return true;
    } else {
      return false;
    }
  }
  
  function to_binary(uint256 x) returns (bytes) {
    if (x == 0) {
        return new bytes(0);
    }
    else {
        byte s = byte(x % 256);
        bytes memory r = new bytes(1);
        r[0] = s;
        return concat(to_binary(x / 256), r);
    }
  }
  
  function concat(bytes byteArray, bytes byteArray2) returns (bytes) {
    bytes memory returnArray = new bytes(byteArray.length + byteArray2.length);
    for (uint16 i = 0; i < byteArray.length; i++) {
        returnArray[i] = byteArray[i];
    }
    for (i; i < (byteArray.length + byteArray2.length); i++) {
        returnArray[i] = byteArray2[i - byteArray.length];
    }
    return returnArray;
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
