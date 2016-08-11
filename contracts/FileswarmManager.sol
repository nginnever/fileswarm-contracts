contract FileswarmManager {
  address public owner;
  address[] public files;
  mapping (address => string[]) public seeders;

  modifier isSeeding(address x)
  {
    if(File(x).seeders(msg.sender) != 0x0) throw;
    _
  }

  function FileswarmManager() {
    owner = msg.sender;
  }
  
  function getFilesCount() public constant returns(uint) {
    return files.length;
  }
  
  function upload(string hash1, string hash2) returns(bool res) {
    address f = new File(msg.sender, msg.value, hash1, hash2);
    files.push(f);
    return true;
  }
  
  function seed(address ifile, string hash1, string hash2) isSeeding(ifile) returns(bool res) {
    seeders[msg.sender].push(hash1);
    seeders[msg.sender].push(hash2);
    File(ifile).addSeeder(msg.sender);
    return true;
  }
  
  function unseed(address ifile, string hash1, string hash2) returns(bool res) {
    if(msg.sender != File(ifile).seeders(msg.sender)) throw;
    seeders[msg.sender].push(hash1);
    seeders[msg.sender].push(hash2);
    File(ifile).removeSeeder(msg.sender);
  }
}

contract File {
  address public owner;
  uint public balance;
  uint public blockNum;
  uint public time;
  uint public challengeNum;
  bool public setTime;
  string public fileHash1;
  string public fileHash2;
  address[] confirmed;
  
  mapping (address => address) public seeders;
  
  modifier isTime()
  {
    if (now < time + 1 minutes) throw;
    _
  }
  
  modifier isChallengeable(address challenger)
  {
    if (seeders[challenger] == 0x0) throw;
    if (now > time + 1 minutes) {
      time = now;
      blockNum = block.number;      
    }
    _
  }
  
  function File(address _owner, uint _balance, string _fileHash1, string _fileHash2) {
    owner = _owner;
    balance = _balance;
    blockNum = block.number;
    setTime = true;
    time = now;
    challengeNum = 0;
    fileHash1 = _fileHash1;
    fileHash2 = _fileHash2;
  }
  
  function setNewChallenge() isTime() {
    time = now;
    blockNum = block.number;
    challengeNum++;
    pay();
  }
  
  function addSeeder(address s) {
    seeders[s] = s;
  }
  
  function removeSeeder(address s) {
    seeders[s] = 0x0;
  }
  
  function challenge() isChallengeable(msg.sender){
    confirmed.push(msg.sender);
  }
  
  function pay() {
    for(uint i = 0; i < confirmed.length - 1; i++) {
      confirmed[i].send(1337);
      delete confirmed[i];
    }
  }
}
