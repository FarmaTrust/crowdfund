pragma solidity ^0.4.18; 

import "./Ownable.sol"; 
import "./SafeMath.sol"; 
import "./TokenVesting.sol";

contract FTT is Ownable {
    using SafeMath for uint256; 

    uint256 public totalSupply = 1000000000 * 10**uint256(decimals); 
    string public constant name = "FarmaTrust Token"; 
    string public symbol = "FTT"; 
    uint8 public constant decimals = 18; 

    mapping(address => uint256) public balances;
    mapping (address => mapping (address => uint256)) internal allowed;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TdeStarted(uint256 startTime);
    event TdeStopped();
    event TdeFinalized();

    // Amount of FTT available during token distribution event. 
    uint256 public constant FT_TOKEN_SALE_CAP = 600000000 * 10**uint256(decimals);

    // Amount held for operational usage.
    uint256 public FT_OPERATIONAL_FUND = totalSupply - FT_TOKEN_SALE_CAP;

    // Amount held for team usage. 
    uint256 public FT_TEAM_FUND = FT_OPERATIONAL_FUND / 10;

    // Amount of FTT issued. 
    uint256 public fttIssued = 0; 

    address public tdeIssuer = 0x2ec9f52a5e4e7b5e20c031c1870fd952e1f01b3e;  
    address public teamVestingAddress; 
    address public unsoldVestingAddress; 
    address public operationalReserveAddress; 
    
    bool public tdeActive; 
    bool public tdeStarted;
    bool public isFinalized; 
    bool public capReached; 
    uint256 public tdeDuration = 60 days;     
    uint256 public tdeStartTime; 

    function FTT() public {

    }

    modifier onlyTdeIssuer {
        require(msg.sender == tdeIssuer); 
        _; 
    }

    modifier tdeRunning {
        require(tdeActive && block.timestamp < tdeStartTime + tdeDuration); 
        _; 
    }

    modifier tdeEnded {
        require(((!tdeActive && block.timestamp > tdeStartTime + tdeDuration) && tdeStarted) || capReached);
        _; 
    }

    function startTde() 
        public 
        onlyOwner 
    {
        require(!isFinalized);
        tdeActive = true;
        tdeStarted = true; 
        if (tdeStartTime == 0) {
            tdeStartTime = block.timestamp;
        } 
        TdeStarted(tdeStartTime);
    }

    function stopTde(bool _restart) 
        external 
        onlyOwner 
    {
      tdeActive = false;
      if (_restart) {
        tdeStartTime = 0;
      } 
      TdeStopped();
    }

    function extendTde(uint256 _time) 
        external 
        onlyOwner 
    {
      tdeDuration = tdeDuration.add(_time);
    }

    function shortenTde(uint256 _time) 
        external 
        onlyOwner 
    {
      tdeDuration = tdeDuration.sub(_time);
    }    

    function setTdeIssuer(address _tdeIssuer) 
        external 
        onlyOwner 
    {
        tdeIssuer = _tdeIssuer;
        balances[tdeIssuer] = FT_TOKEN_SALE_CAP;
    }

    function setOperationalReserveAddress(address _operationalReserveAddress) 
        external 
        onlyOwner 
        tdeRunning 
    {
        operationalReserveAddress = _operationalReserveAddress;
    }    

    function issueFTT(address _user, uint256 _fttAmount) 
        public 
        onlyTdeIssuer 
        tdeRunning 
        returns(bool)
    {
        uint256 newAmountIssued = fttIssued.add(_fttAmount); 
        require(_user != address(0)); 
        require(_fttAmount > 0); 
        require(newAmountIssued <= FT_TOKEN_SALE_CAP); 
        
        balances[_user] = balances[_user].add(_fttAmount); 

        fttIssued = newAmountIssued; 
        Transfer(0x0, _user, _fttAmount); 

        if (fttIssued == FT_TOKEN_SALE_CAP) {
            capReached = true; 
        }

        return true; 
    }

    function fttIssued()
        external 
        view
        returns (uint256)
    {
        return fttIssued; 
    }

    function finalize() 
        external 
        tdeEnded 
        onlyOwner 
    {
        require(!isFinalized);          
        
        // Deposit team fund amount into team vesting contract.
        uint256 teamVestingCliff = 15778476;  // 6 months 
        uint256 teamVestingDuration = 1 years; 
        TokenVesting teamVesting = new TokenVesting(owner, now, teamVestingCliff, teamVestingDuration, false);
        teamVesting.transferOwnership(owner);   
        teamVestingAddress = address(teamVesting); 
        balances[teamVestingAddress] = FT_TEAM_FUND; 
         
        if (!capReached) {
            // Deposit unsold FTT into unsold vesting contract.
            uint256 unsoldVestingCliff = 3 years; 
            uint256 unsoldVestingDuration = 10 years; 
            TokenVesting unsoldVesting = new TokenVesting(owner, now, unsoldVestingCliff, unsoldVestingDuration, false); 
            unsoldVesting.transferOwnership(owner);            
            unsoldVestingAddress = address(unsoldVesting); 
            balances[unsoldVestingAddress] = FT_TOKEN_SALE_CAP - fttIssued;             
        }

        // Allocate operational reserve of FTT. 
        balances[operationalReserveAddress] = FT_OPERATIONAL_FUND - FT_TEAM_FUND;

        isFinalized = true;
        TdeFinalized();
    }

    function transferFrom(address _from, address _to, uint256 _value) 
        public 
        returns (bool) 
    {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }
 
    function transfer(address _to, uint256 _value) 
        public 
        returns (bool) 
    {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        // SafeMath.sub will throw if there is not enough balance.
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }   

    function approve(address _spender, uint256 _value) 
        public 
        returns (bool) 
    {
        require(_spender != address(0)); 
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }       

    function balanceOf(address _owner) 
        public 
        view 
        returns (uint256 balance) 
    {
        return balances[_owner];
    }     

    function allowance(address _owner, address _spender) 
        public 
        view 
        returns (uint256) 
    {
        return allowed[_owner][_spender];
    }    
}
