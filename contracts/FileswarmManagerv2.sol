contract FileswarmManager {
  address public owner;
  uint public filecount;
  address[] public files;

  struct Files {
     bytes32 hash;
     address owner;
     address lastFile;
  }
  
  struct Seed {
    bytes32 hash;
  }
  
  mapping (address => Seed) public seeders;
  mapping (address => Files) public userFiles;

  modifier isSeeding(address x)
  {
    if(File(x).getSeederAddr(msg.sender) != 0x0) throw;
    _;
  }
  
  modifier isOwner(address x)
  {
    if(userFiles[x].owner != 0x0 && userFiles[x].owner != x) throw;
    _;
  }

  function FileswarmManager() {
    owner = msg.sender;
  }
  
  // init new file contracts with the hash of the file, the address of the file 
  // is stored in userFiles lastFile and in the ipfs hash stored in the hash field
  function createFile(bytes32 _uhash, bytes32 _fhash) isOwner(msg.sender) payable{
    address f = new File(msg.sender, msg.value, _fhash);
    Files newFile = userFiles[msg.sender];
    newFile.hash = _uhash;
    newFile.lastFile = f;
    if (newFile.owner == 0x0) newFile.owner = msg.sender;
    filecount++;
    files.push(f);
  }
  
  function seed(address ifile, bytes32 _hash) isSeeding(ifile) returns(bool res) {
    Seed entry = seeders[msg.sender];
    // this hash logs all of the chunks a seeder is seeding for client side ops
    entry.hash = _hash;
    File(ifile).addSeeder(msg.sender);
    return true;
  }
  
  function getUser(address u) public constant returns(bytes32 hash, address owner, address lastfile) {
    Files temp = userFiles[u];
    return (temp.hash, temp.owner, temp.lastFile);
  }
}

contract File {
  address owner;
  uint public balance;
  uint blockNum;
  uint time;
  uint rand;
  uint public round;
  uint public numSeeders;
  // TODO kick seeders off a chunk after missing x rounds
  uint public allowedMissedRounds;
  bool public test;
  bytes32 public fileHash;
  bytes32[] public chunks;
  bytes32 public challengeHash;
  uint amt = 150;
  
  // IPFS protobuf encodings
  bytes merkledagprefix = hex"0a";
  bytes unixfsprefix = hex"080212";
  bytes postfix = hex"18";
  bytes32 sha;
  
  
  struct Seeder {
    uint amountRewarded;
    address seeder;
    uint challengeNum;
  }
  
  //mapping (uint => Chunk) public chunks;
  mapping (address => Seeder) public seeders;
  
  modifier isTime()
  {
    if (now < time + 1 minutes) throw;
    _;
  }
  
  modifier isChallengeable(address challenger)
  {
     if (seeders[challenger].seeder != challenger || seeders[challenger].challengeNum >= round) throw;
    _;
  }
  
  function File(address o, uint b, bytes32 h) {
    owner = o;
    balance = b;
    blockNum = block.number;
    time = now;
    round = 1;
    fileHash = h;
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
  }
  
  function addSeeder(address s) {
    // Throw if the sender is already seeding a chunk of this file
    if(seeders[s].seeder != 0x0) throw;
    // Throw if the file has more than 4 seeders already
    if(numSeeders > 4) throw;
    seeders[s].seeder = s;
    seeders[s].amountRewarded = 0;
    seeders[s].challengeNum = 0;
  }
  
  function challenge(bytes chunk) isChallengeable(msg.sender) payable{
    if(IPFSvalidate(chunk)) {
      test = msg.sender.send(amt);
      balance = balance - amt;
      seeders[msg.sender].challengeNum = round;
      seeders[msg.sender].amountRewarded += amt;
    }
  }
  
  function IPFSvalidate(bytes chunk) internal returns(bool) {
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
