# FarmaTrust TDE
FarmaTrust Token Distribution Event contracts originally by Matthew Di Ferrante.

# FarmaTrust ERC20 Token (FTT)

The FTT contract implements an ERC20 token with some management functionality. There are no known security issues with the contract.

The contract address is `0x2AEC18c5500f21359CE1BEA5Dc1777344dF4C0Dc`

### FTT.sol

The FTT token contract is self contained in that it implements both an ERC20 Token with some crowdsale workflow and management functionality. 

```
contract FTT is Ownable {
	using SafeMath for  uint256;
```
`SafeMath` is used throughout the entire contract.

### Constructor 

```
function FTT() public {
}
```
The constructor itself does not perform any intialization tasks, as none are required. 

> While the contract owner is not set within the contract constructor, the FTT contract inherits `Ownable.sol` (as shown above) where the FTT contract owner is set within its constructor. 
```
function Ownable() public {
	owner =  msg.sender;
}
```
## Standard ERC20 Functions

### transfer 

```
    function transfer(address _to, uint256 _value)
	    public
	    returns(bool) 
	{
        if (!isFinalized) return false;
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender, _to, _value);
        return true;
    }
```
The `transfer` function implements the standard ERC20 transfer capability with a number of additional `require` checks.  

> `if (!isFinalized) return false;`

In particular, the check shown above ensures that the FTT token cannot be transferred while the `isFinalized` global variable is set to `false` .  This ensures that the FTT token cannot be traded publicly until the token distribution event (TDE) has been completed. 

### transferFrom 

```
    function transferFrom(address _from, address _to, uint256 _value)
	    public
	    returns(bool) 
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
```
The `transferFrom` function implements the standard ERC20 transfer capability with a number of additional `require` checks.  

> `if (!isFinalized) return false;`

As with,`transfer` the check shown above ensures that the FTT token cannot be transferred before the TDE is complete. 

### approve 

```
    function approve(address _spender, uint256 _value)
    	public
    	returns(bool) 
   {
        require(_spender != address(0));
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }
```
The `approve` function implements functionality as described by the ERC20 standard, with an additional extra check that ensures zero address cannot be used as an argument for the parameter `spender`.
Invocation of `approve` updates the `allowed` mapping, authorizing the `spender` to transfer FTT on behalf of the owner.  

### balanceOf 

```
function balanceOf(address _owner)
	public
	view
	returns (uint256 balance)
{
	return balances[_owner];
}
```
`balanceOf` returns the FTT balance of  the `_owner` address, as described by the ERC20 standard.  

### allowance

```
    function allowance(address _owner, address _spender)
    	public
    	view
    	returns(uint256) 
    {
        return allowed[_owner][_spender];
    }
```
`allowance` returns the allowance of an approved `spender` contained within the `allowed` mapping, as described by the ERC20 standard.  

## Management Functions

### startTde 

```
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
```
The `startTde` function allows the FTT contract owner to begin the TDE.  Note that in order for the function to execute successfully, the `isFinalized` global variable must be set to `false`.  Finally an event is emitted which logs the TDE start time. 

### stopTde

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

The `stopTde` function allows the FTT contract owner to pause the TDE.  The `onlyOwner` modifier ensures that no other EAO or contract may stop the TDE.  The function also includes the ability to reset the TDE start time.  Finally, the `TdeStopped` event is emitted which logs the time at which the TDE was paused. 

### extendTde 
    function extendTde(uint256 _time) 
        external 
        onlyOwner 
    {
      tdeDuration = tdeDuration.add(_time);
    }

The `extendTde` function allows the FTT contract owner to extend the duration of the TDE.  The amount of time to be extended is designated by the parameter `_time` and must be given in seconds. 

### shortenTde 
    function shortenTde(uint256 _time) 
        external 
        onlyOwner 
    {
      tdeDuration = tdeDuration.sub(_time);
    }    
The function `shortenTde` allows the FTT contract owner to shorten the TDE duration.  The amount of time deducted from the TDE duration must be given in the `_time` parameter as seconds. 

### setTdeIssuer 
    function setTdeIssuer(address _tdeIssuer) 
        external 
        onlyOwner 
    {
        tdeIssuer = _tdeIssuer;
    }

The `setTdeIssuer` function allows the owner to set the `tdeIssuer` address.  The TDE issuer can mint and then grant FTT for FarmaTrust contributors. 

### issueFTT 

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

The `issueFTT` function can only be called by the TdeIssuer address, and only while the TDE is running. It creates new FTT tokens and assigns them to the chosen FarmaTrust contributor address.  The amount of FTT that can be created can only be less than or equal to `FT_TOKEN_SALE_CAP` (600 Million)

### fttIssued 

    function fttIssued()
        external 
        view
        returns (uint256)
    {
        return fttIssued; 
    }

The `fttIssued` function returns the amount of FTT issued to date. 

### finalize 

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

The `finalize` function can only be called while the TDE is stopped by the FTT contract owner and results in finalizing the end of the TDE.   Once the TDE is finalized, it cannot be restarted and the events that finalization triggers cannot be automatically reversed.  

On finalization, the following actions occur: 
- A token vesting contract is instantiated, and the `FT_TEAM_FUND`  amount is allocated to the token vesting address. 
- If the cap is not reached, a token vesting contract is instantiated, and the amount of unsold FTT is allocated to the token vesting address. 
- FTT equalling the `FT_OPERATIONAL_FUND` minus the `FT_TEAM_FUND` is allocated to the operational reserve address
- The global variable `isFinalized` is set to true. 
- The event `TdeFinalized` is fired, and the time of finalization is logged. 
