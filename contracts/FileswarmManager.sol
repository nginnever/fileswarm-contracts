contract FileswarmManager {
  address owner;
  mapping (address => address[]) files;
  
  modifier isOwner(bytes32 name)
  {
    if (msg.sender != owner) throw;
    _
  }

  function FileswarmManager() {
    owner = msg.sender;
  }
  
  function upload(uint TTL) returns (bool res) {
    address f = new File(msg.sender, msg.value);
    files[msg.sender].push(f);
    return true;
  }
  
}

contract File {
  address owner;
  uint balance;
  
  function File(address s, uint v) {
    owner = s;
    balance = v;
  }
}
