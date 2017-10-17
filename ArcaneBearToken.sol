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

    uint256     public      totalSupply;
    uint8       public      decimals;
    string      public      name;
    string      public      symbol;
    bool        public      contractLaunched;
    bool        public      transfersFrozen;
    bool        public      tokenMintingEnabled;

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowance;

    event Transfer(address indexed _sender, address indexed _recipient, uint256 _amount);
    event Approval(address indexed _owner, address indexed _spender, uint256 _amount);
    event FreezeTransfers(address indexed _invoker, bool indexed _transfersFrozen);
    event ThawTransfers(address indexed _invoker, bool indexed _transfersThawed);
    event MintToken(address indexed _invoker, address indexed _recipient, uint256 _tokensMinted, bool indexed _minted);
    event BurnTokens(address indexed _invoker, uint256 _amountBurned, bool indexed _burned);

    function ArcaneBearToken() {
        totalSupply = 200000000000000000000000000;
        decimals = 18;
        name = "ArcaneBearToken";
        symbol = "BEAR";
        balances[msg.sender] = 200000000000000000000000000;
        tokenMintingEnabled = false;
        contractLaunched = false;
        transfersFrozen = true;
    }

    /// @notice Used to launch the contract, enable transfers, and enable token minting
    function launchContract()
        public
        onlyAdmin
        returns (bool launched)
    {
        require(!contractLaunched);
        contractLaunched = true;
        tokenMintingEnabled = true;
        transfersFrozen = false;
        return true;
    }

    function freezeTransfers()
        public
        onlyAdmin
        returns (bool frozen)
    {
        require(!transfersFrozen);
        transfersFrozen = true;
        FreezeTransfers(msg.sender, true);
        return true;
    }

    function thawTransfers()
        public
        onlyAdmin
        returns (bool frozen)
    {
        require(transfersFrozen);
        transfersFrozen = false;
        ThawTransfers(msg.sender, true);
        return true;
    }

    function mintingValidation(uint256 _amountMint, address _recipient)
        private
        constant
        returns (bool valid)
    {
        require(_amountMint > 0);
        require(_recipient != address(0x0));
        require(totalSupply.add(_amountMint) > totalSupply);
        require(balances[_recipient].add(_amountMint) > balances[_recipient]);
        return true;
    }

    function mintTokens(uint256 _amountMint, address _recipient)
        public
        onlyAdmin
        returns (bool minted)
    {
        require(mintingValidation(_amountMint, _recipient));
        totalSupply = totalSupply.add(_amountMint);
        balances[_recipient] = balances[_recipient].add(_amountMint);
        Transfer(0, _recipient, _amountMint);
        MintToken(msg.sender, _recipient, _amountMint, true);
        return true;
    }

    function burnValidation(uint256 _amountBurn)
        private
        constant
        returns (bool valid)
    {
        require(totalSupply > _amountBurn);
        require(balances[owner] > _amountBurn);
        require(totalSupply.sub(_amountBurn) > 0);
        require(balances[owner].sub(_amountBurn) > 0);
        return true;
    }

    function burnTokens(uint256 _amountBurn)
        public
        onlyAdmin
        returns (bool burned)
    {
        require(burnValidation(_amountBurn));
        balances[owner] = balances[owner].sub(_amountBurn);
        totalSupply = totalSupply.sub(_amountBurn);
        Transfer(owner, 0, _amountBurn);
        BurnTokens(msg.sender, _amountBurn, true);
        return true;
    }

    function transferCheck(address _msgSender, address _recipient, uint256 _amount)
        private
        constant
        returns (bool valid)
    {
        require(!transfersFrozen);
        require(_amount > 0);
        require(_recipient != address(0x0));
        require(balances[_msgSender] >= _amount);
        require(balances[_msgSender].sub(_amount) >= 0);
        require(balances[_recipient].add(_amount) > balances[_recipient]);
        return true;
    }
    function transfer(address _recipient, uint256 _amount)
        public
        returns (bool transferred)
    {
        require(transferCheck(msg.sender, _recipient, _amount));
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        balances[_recipient] = balances[_recipient].add(_amount);
        return true;
    }

    function transferFrom(address _owner, address _recipient, uint256 _amount)
        public
        returns (bool transferred)
    {
        require(allowance[_owner][msg.sender] >= _amount);
        require(allowance[_owner][msg.sender].sub(_amount) >= 0);
        require(transferCheck(_owner, _recipient, _amount));
        allowance[_owner][msg.sender] = allowance[_owner][msg.sender].sub(_amount);
        balances[_owner] = balances[_owner].sub(_amount);
        balances[_recipient] = balances[_recipient].add(_amount);
        Transfer(_owner, _recipient, _amount);
        return true;
    }

    function approve(address _spender, uint256 _allowance)
        public
        returns (bool transferred)
    {
        require(balances[msg.sender] >= _allowance);
        require(allowance[msg.sender][_spender].add(_allowance) > allowance[msg.sender][_spender]);
        allowance[msg.sender][_spender] = _allowance;
        Approval(msg.sender, _spender, _allowance);
        return true;
    }

    //GETTERS//

    function totalSupply()
        constant
        returns (uint256 _totalSupply)
    {
        return totalSupply;
    }

    function balanceOf(address _owner)
        constant
        returns (uint256 balance)
    {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender)
        constant
        returns (uint256 _allowance)
    {
        return allowance[_owner][_spender];
    }
}