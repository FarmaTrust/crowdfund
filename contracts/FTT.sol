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
    event FTTIssued(address indexed from, address indexed to, uint256 indexed amount, uint256 timestamp); 
    event TdeStarted(uint256 startTime);
    event TdeStopped(uint256 stopTime);
    event TdeFinalized(uint256 finalizeTime);

    // Amount of FTT available during token distribution event. 
    uint256 public constant FT_TOKEN_SALE_CAP = 600000000 * 10**uint256(decimals);

    // Amount held for operational usage.
    uint256 public FT_OPERATIONAL_FUND = totalSupply - FT_TOKEN_SALE_CAP;

    // Amount held for team usage. 
    uint256 public FT_TEAM_FUND = FT_OPERATIONAL_FUND / 10;

    // Amount of FTT issued. 
    uint256 public fttIssued = 0; 

    address public tdeIssuer;  
    address public teamVestingAddress; 
    address public unsoldVestingAddress; 
    address public operationalReserveAddress; 
    
    bool public tdeActive; 
    bool public tdeStarted;
    bool public isFinalized = false; 
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

    /**
     * @dev Allows contract owner to start the TDE. 
     */
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

    /**
     * @dev Allows contract owner to stop and optionally restart the TDE. 
     * @param _restart Resets the tdeStartTime if true.
     */
    function stopTde(bool _restart) 
        external 
        onlyOwner 
    {
      tdeActive = false;
      if (_restart) {
        tdeStartTime = 0;
      } 
      TdeStopped(block.timestamp);
    }

    /**
     * @dev Allows contract owner to increase TDE period. 
     * @param _time amount of time to increase TDE period by.
     */
    function extendTde(uint256 _time) 
        external 
        onlyOwner 
    {
      tdeDuration = tdeDuration.add(_time);
    }

    /**
     * @dev Allows contract owner to reduce TDE period. 
     * @_time amount of time to reduce TDE period by.
     */
    function shortenTde(uint256 _time) 
        external 
        onlyOwner 
    {
      tdeDuration = tdeDuration.sub(_time);
    }    

    /**
     * @dev Allows contract owner to set the FTT issuing authority. 
     * @param _tdeIssuer address of FTT issuing authority.
     */
    function setTdeIssuer(address _tdeIssuer) 
        external 
        onlyOwner 
    {
        tdeIssuer = _tdeIssuer;
    }

    /**
     * @dev Allows contract owner to set the beneficiary of the FT operational reserve amount of FTT.
     * @param _operationalReserveAddress address of FT operational reserve beneficiary.
     */
    function setOperationalReserveAddress(address _operationalReserveAddress) 
        external 
        onlyOwner 
        tdeRunning 
    {
        operationalReserveAddress = _operationalReserveAddress;
    }    

    /**
     * @dev Issues FTT to entitled accounts.
     * @param _user address to issue FTT to. 
     * @param _fttAmount amount of FTT to issue. 
     */
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
        FTTIssued(tdeIssuer, _user, _fttAmount, block.timestamp); 

        if (fttIssued == FT_TOKEN_SALE_CAP) {
            capReached = true; 
        }

        return true; 
    }

    /**
     * @dev Returns amount of FTT issued.
     */
    function fttIssued()
        external 
        view
        returns (uint256)
    {
        return fttIssued; 
    }

    /**
     * @dev Allows the contract owner to finalize the TDE.
     */
    function finalize() 
        external 
        tdeEnded 
        onlyOwner 
    {
        require(!isFinalized);          
        
        // Deposit team fund amount into team vesting contract.
        uint256 teamVestingCliff = 15778476;  // 6 months 
        uint256 teamVestingDuration = 1 years; 
        TokenVesting teamVesting = new TokenVesting(owner, now, teamVestingCliff, teamVestingDuration, true);
        teamVesting.transferOwnership(owner);   
        teamVestingAddress = address(teamVesting); 
        balances[teamVestingAddress] = FT_TEAM_FUND; 
         
        if (!capReached) {
            // Deposit unsold FTT into unsold vesting contract.
            uint256 unsoldVestingCliff = 3 years; 
            uint256 unsoldVestingDuration = 10 years; 
            TokenVesting unsoldVesting = new TokenVesting(owner, now, unsoldVestingCliff, unsoldVestingDuration, true); 
            unsoldVesting.transferOwnership(owner);            
            unsoldVestingAddress = address(unsoldVesting); 
            balances[unsoldVestingAddress] = FT_TOKEN_SALE_CAP - fttIssued;             
        }

        // Allocate operational reserve of FTT. 
        balances[operationalReserveAddress] = FT_OPERATIONAL_FUND - FT_TEAM_FUND;

        isFinalized = true;
        TdeFinalized(block.timestamp);
    }

    /**
     * @dev Transfer tokens from one address to another. Trading limited - requires the TDE to have ended.
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address _from, address _to, uint256 _value) 
        public 
        returns (bool) 
    {
        if (!isFinalized) return false;
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }
 
     /**
    * @dev Transfer token for a specified address.  Trading limited - requires the TDE to have ended.
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) 
        public 
        returns (bool) 
    {
        if (!isFinalized) return false;
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }   

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     *
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to be spent.
     */
    function approve(address _spender, uint256 _value) 
        public 
        returns (bool) 
    {
        require(_spender != address(0)); 
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }       

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) 
        public 
        view 
        returns (uint256 balance) 
    {
        return balances[_owner];
    }     

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address _owner, address _spender) 
        public 
        view 
        returns (uint256) 
    {
        return allowed[_owner][_spender];
    }    

    /**
     * approve should be called when allowed[_spender] == 0. To increment
     * allowed value, it is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     */
    function increaseApproval (address _spender, uint _addedValue) 
        public 
        returns (bool success) 
    {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval (address _spender, uint _subtractedValue) 
        public 
        returns (bool success) 
    {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }    
}
