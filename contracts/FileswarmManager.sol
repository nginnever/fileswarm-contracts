contract FileswarmManager {
  address owner;
  address[] files;
  mapping (address => address[]) seeders;

  modifier isSeeding(address x)
  {
    if(File(x).seeders(msg.sender) != 0x0) throw;
    _
  }

  function FileswarmManager() {
    owner = msg.sender;
  }
  
  function upload(string hash1, string hash2) returns(bool res) {
    address f = new File(msg.sender, msg.value, hash1, hash2);
    files.push(f);
    return true;
  }
  
  function seed(address ifile) isSeeding(ifile) returns(bool res) {
    seeders[msg.sender].push(ifile);
    File(ifile).addSeeder(msg.sender);
  }
  
  function unseed(address ifile) returns(bool res) {
    if(msg.sender != File(ifile).seeders(msg.sender)) throw;
    File(ifile).removeSeeder(msg.sender);
  }
  
  function challenge() returns(bool res) {

  }
  
}

contract File {
  address owner;
  uint balance;
  uint blockNum;
  uint time;
  bool setTime;
  string fileHash1;
  string fileHash2;
  
  mapping (address => address) public seeders;
  
  modifier setChallenge()
  {
    if (now < time + 1 minutes) throw;
    time = now;
    blockNum = block.number;
    _
  }
  
  modifier isChallengeable(address challenger)
  {
    if (now < time + 1 minutes) throw;
    if (setTime) time = now;
    _
  }
  
  function File(address s, uint v, string hash1, string hash2) {
    owner = s;
    balance = v;
    setTime = true;
    time = now;
    fileHash1 = hash1;
    fileHash2 = hash2;
  }
  
  function addSeeder(address s) {
    seeders[s] = s;
  }
  function removeSeeder(address s) {
    seeders[s] = 0x0;
  }  
}
