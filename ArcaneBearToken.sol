pragma solidity 0.4.16;

// implement safemath as a library
library SafeMath {

  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    require(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    require(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }
}

// Used for function invoke restriction
contract Administration {

    address     public owner; // temporary address
    
    mapping (address => bool) public moderators;

    event AddMod(address indexed _invoker, address indexed _newMod, bool indexed _modAdded);
    event RemoveMod(address indexed _invoker, address indexed _removeMod, bool indexed _modRemoved);

    function Administration() {
        owner = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner || moderators[msg.sender] == true);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _; // function code inserted here
    }

    function transferOwnership(address _newOwner) onlyOwner returns (bool success) {
        owner = _newOwner;
        return true;
        
    }

    function addModerator(address _newMod) onlyOwner returns (bool added) {
        moderators[_newMod] = true;
        AddMod(msg.sender, _newMod, true);
        return true;
    }
    
    function removeModerator(address _removeMod) onlyOwner returns (bool removed) {
        moderators[_removeMod] = false;
        RemoveMod(msg.sender, _removeMod, true);
        return true;
    }

}


contract ArcaneBearToken is Administration {
    using SafeMath for uint256;




}