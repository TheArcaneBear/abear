pragma solidity 0.4.16;

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
    uint256 public periodOneEnd; // 1 day
    uint256 public periodOneBonus; // 10%
    uint256 public periodTwoEnd; // 2nd day to 7 day
    uint256 public periodTwoBonus; // 5%
    uint256 public periodThreeEnd; // 8day - 14 day 
    uint256 public periodThreeBonus; // 2%
    uint256 public periodFourEnd; // 15 day - 30 day
    uint256 public currentPeriodBonus;
    uint256 public tokenSold;
    uint256 public softCap = 12000000000000000000000000;
    uint256 public hardCap = 108000000000000000000000000;
    bool    public contractLaunched;
    bool    public crowdsaleLaunched;
    bool    public crowdsalePaused;
    bool    public crowdsaleClosed; // this is only set to true at the beginning and end
    bool    public withdrawalsEnabled;
    ArcaneBearToken public bearToken;

    mapping (address => uint256) public balances;
    mapping (address => uint256) public ethBalances;
    
    event LaunchCrowdsale(address indexed _invoker, bool indexed _launched);
    event PauseCrowdsale(address indexed _invoker, bool indexed _paused);
    event ResumeCrowdsale(address indexed _invoker, bool indexed _resumed);
    event LogContribution(address _backer, uint256 _bearTokensBought, uint256 _amountEther, bool _contributed);
    event LogRefund(address indexed _backer, uint256 indexed _amountEther, bool indexed _refunded);
    event TokenTransfer(address indexed _sender, address indexed _recipient, uint256 _amount);
    
    modifier preLaunch() {
        require(!contractLaunched);
        _;
    }

    modifier afterLaunch() {
        require(contractLaunched);
        _;
    }

    modifier withdrawalEnabled() {
        require(withdrawalsEnabled);
        _;
    }

    function Crowdsale(address _bearTokenContractAddress, address _hotWallet, uint256 _crowdsaleReserve) {
        bearToken = ArcaneBearToken(_bearTokenContractAddress);
        hotWallet = _hotWallet;
        contractLaunched = false;
        crowdsaleLaunched = false;
        crowdsalePaused = true;
        crowdsaleClosed = true;
        crowdsaleReserve = _crowdsaleReserve;
    }
    
    function() payable {
        require(!crowdsaleClosed);
        require(contribute(msg.sender));
    }



    function launchedContract() 
        public
        onlyAdmin
        preLaunch
        returns (bool launched)
    {
        periodOneEnd = now + 1 days;
        periodTwoEnd = now + 7 days;
        periodThreeEnd = now + 14 days;
        periodFourEnd = now + 30 days;
        periodOneBonus = 100000000000000000;
        periodTwoBonus = 50000000000000000;
        periodThreeBonus = 20000000000000000;
        crowdsalePaused = false;
        crowdsaleClosed = false;
        crowdsaleLaunched = true;
        contractLaunched = true;
        tokenSold = 0;
        balances[owner] = crowdsaleReserve;
        currentPeriodBonus = periodOneBonus;
        LaunchCrowdsale(msg.sender, true);
        return true;
    }

    function enableWithdrawals()
        public
        onlyAdmin
        afterLaunch
        returns (bool _withdrawalsEnabled)
    {
        withdrawalsEnabled = true;
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

    function broadcastWithdrawal(address _backer)
        public
        onlyAdmin
        withdrawalEnabled
        returns (bool _withdrawn)
    {
        require(balances[_backer] > 0);
        uint256 _rewardAmount = balances[_backer];
        balances[_backer] = 0;
        bearToken.transfer(_backer, _rewardAmount);
        TokenTransfer(this, _backer, _rewardAmount);
        return true;
    }

    function withdrawBEAR()
        public
        withdrawalEnabled
        returns (bool _withdrawn)
    {
        require(balances[msg.sender] > 0);
        uint256 _rewardAmount = balances[msg.sender];
        balances[msg.sender] = 0;
        bearToken.transfer(msg.sender, _rewardAmount);
        TokenTransfer(this, msg.sender, _rewardAmount);
        return true;
    }

    function withdrawEth()
        public
        returns (bool _ethWithdrawn)
    {
        require(ethBalances[msg.sender] > 0);
        uint256 _refundAmount = ethBalances[msg.sender];
        ethBalances[msg.sender] = 0;
        msg.sender.transfer(_refundAmount);
        LogRefund(msg.sender, _refundAmount, true);
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

    function currentPeriodCheck()
        private
        returns (bool valid)
    {
        // disable bonus
        if (now >= periodThreeEnd) {
            currentPeriodBonus = 0;
        } else if (now >= periodTwoEnd) {
            currentPeriodBonus = periodThreeBonus;
        } else if (now >= periodOneEnd) {
            currentPeriodBonus = periodTwoBonus;
        } else {
            currentPeriodBonus = periodOneBonus;
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

    function contribute(address _backer)
        payable
        returns (bool _contributed)
    {
        require(contractLaunched);
        require(now <= periodFourEnd);
        require(!crowdsalePaused);
        require(_backer != address(0x0));
        require(msg.value >= minContributionAmount);
        // Run a period check to determine how much of a bonus they get.
        require(currentPeriodCheck());
        uint256 _amountBEAR = msg.value / tokenCostInWei;
        uint256 amountBEAR = _amountBEAR.mul(1 ether);
        uint256 amountCharged = 0;
        uint256 amountRefund = 0;
        if (currentPeriodBonus > 0) {
            uint256 _bonusAmount = amountBEAR.mul(currentPeriodBonus);
            uint256 bonusAmount = _bonusAmount.div(1 ether);
            amountBEAR = amountBEAR.add(bonusAmount);
        }
        if (amountBEAR >= remainingTokens) {
            amountBEAR = remainingTokens;
            uint256 _amountCharged = amountBEAR.div(tokenCostInWei);
            amountCharged = _amountCharged.mul(1 ether);
            amountRefund = msg.value.sub(amountCharged);
            // No more tokens available so lets end the crowdsale
            crowdsaleClosed = true;
        } else {
            amountCharged = msg.value;
        }
        if (amountRefund > 0) {
            require(refundCalculation(_backer, amountRefund));
        }
        require(balances[this].sub(amountBEAR) >= 0);
        require(balances[_backer].add(amountBEAR) > balances[_backer]);
        balances[this] = balances[this].sub(amountBEAR);
        balances[_backer] = balances[_backer].add(amountBEAR);
        hotWallet.transfer(amountCharged);
        LogContribution(_backer, amountBEAR, amountCharged, true);
        return true;
    }
}