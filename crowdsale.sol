pragma solidity 0.4.15;

interface ArcaneBearToken {

    function transfer(address _recipient, uint256 _amount);

}

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
        require(_newMod != address(0x0));
        moderators[_newMod] = true;
        AddMod(msg.sender, _newMod, true);
        return true;
    }
    
    function removeModerator(address _removeMod) onlyOwner returns (bool removed) {
        require(_removeMod != address(0x0));
        moderators[_removeMod] = false;
        RemoveMod(msg.sender, _removeMod, true);
        return true;
    }

}


contract Crowdsale is Administration {
    using SafeMath for uint256;

    address public hotWallet;
    uint256 public crowdsaleReserve;
    uint256 public remainingTokens;
    uint256 public tokenCostInWei;
    uint256 public minContributionAmount; 
    uint256 public tierOnePrice;
    uint256 public tierOneMax;
    uint256 public tierTwoPrice;
    uint256 public tierTwoMax;
    uint256 public currentPriceTier;
    uint256 public tokenSold;
    bool    public contractLaunched;
    bool    public crowdsaleLaunched;
    bool    public crowdsalePaused;
    ArcaneBearToken public bearToken;

    mapping (address => uint256) public balances;
    mapping (address => uint256) public ethBalances;
    
    event LaunchCrowdsale(address indexed _invoker, bool indexed _launched);
    event PauseCrowdsale(address indexed _invoker, bool indexed _paused);
    event ResumeCrowdsale(address indexed _invoker, bool indexed _resumed);
    event LogContribution(address _backer, uint256 _bearTokensBought, uint256 _amountEther, bool _contributed);

    modifier preLaunch() {
        require(!contractLaunched);
        _;
    }

    modifier afterLaunch() {
        require(contractLaunched);
        _;
    }

    function Crowdsale(address _bearTokenContractAddress, address _hotWallet, uint256 _crowdsaleReserve) {
        bearToken = ArcaneBearToken(_bearTokenContractAddress);
        hotWallet = _hotWallet;
        contractLaunched = false;
        crowdsaleLaunched = false;
        crowdsalePaused = true;
        crowdsaleReserve = _crowdsaleReserve;
    }
    
    function() payable {
        contribute(msg.sender);
    }



    function launchedContract() 
        public
        onlyAdmin
        preLaunch
        returns (bool launched)
    {

        currentPriceTier = tierOnePrice;
        crowdsalePaused = false;
        crowdsaleLaunched = true;
        contractLaunched = true;
        tokenSold = 0;
        balances[owner] = crowdsaleReserve;
        LaunchCrowdsale(msg.sender, true);
        return true;
    }


    function pauseCrowdsale() 
        public
        onlyAdmin
        afterLaunch
        returns (bool paused)
    {
        require(!crowdsalePaused);
        crowdsalePaused = true;
        PauseCrowdsale(msg.sender, true);
        return true;
    }

    function resumeCrowdsale()
        public
        onlyAdmin
        afterLaunch
        returns (bool paused)
    {
        require(crowdsalePaused);
        crowdsalePaused = false;
        ResumeCrowdsale(msg.sender, true);
        return true;
    }

    function priceTierCheck()
        private
        returns (bool valid)
    {
        if (tokenSold >= tierOneMax) {
            currentPriceTier = tierTwoPrice;
        }
        return true;
    }

    function refundCalculation(address _backer, uint256 _amountRefund)
        private
        returns (bool valid)
    {
        require(ethBalances[_backer].add(_amountRefund) > ethBalances[_backer]);
        ethBalances[_backer] = ethBalances[_backer].add(_amountRefund);
        return true;
    }

    function contribute(address _backer) payable {
        require(contractLaunched);
        require(!crowdsalePaused);
        require(_backer != address(0x0));
        require(msg.value >= minContributionAmount);
        uint256 _amountBEAR = msg.value.div(tokenCostInWei);
        uint256 amountBEAR = _amountBEAR.mul(1 ether);
        uint256 amountCharged = 0;
        uint256 amountRefund = 0;
        if (amountBEAR >= remainingTokens) {
            amountBEAR = remainingTokens;
            uint256 _amountCharged = amountBEAR.div(tokenCostInWei);
            amountCharged = _amountCharged.mul(1 ether);
            amountRefund = msg.value.sub(amountCharged);
        } else {
            amountCharged = msg.value;
        }
        if (amountRefund > 0) {
            require(refundCalculation(_backer, amountRefund));
        }
        require(balances[owner].sub(amountBEAR) >= 0);
        require(balances[_backer].add(amountBEAR) > balances[_backer]);
        balances[owner] = balances[owner].sub(amountBEAR);
        balances[_backer] = balances[_backer].add(amountBEAR);
        hotWallet.transfer(amountCharged);
        LogContribution(_backer, amountBEAR, amountCharged, true);
    }
}