pragma solidity ^0.4.0;

import "./ERC223ReceivingContract.sol";
import "./SafeMath.sol";
import "./ERC20.sol";
import "./Token.sol";
import "./Ownable.sol";

contract TokenDistribution is ERC223ReceivingContract, Ownable {

  using SafeMath for uint;

  Token private _token;

  uint private _start;
  uint private _end;

  uint private _price;
  uint private _limit;
  uint private _available;
  uint public _cap;

  address public _beneficiary;
  address _unsoldTokenBeneficiary;
  
  uint public collected;
  bool public isFinalized = false;  
  bool public capReached = false;

  mapping (address => uint256) public whitelist;
  mapping (address => uint) private _limits;

  event Buy(address beneficiary, uint amount, uint value);
  event GoalReached(uint amountRaised);
  event PresaleContribution(address indexed holder, uint256 tokens);

  enum FundingPhase {
    Phase1,
    Phase2,
    Phase3        
  }  

  FundingPhase phase; 

  modifier evalFundingPhase {
    if(now <= (_start + 1 weeks) && 
       _available >= 525000000) {
         phase = FundingPhase.Phase1;
       } else if (now <= (_start + 1 weeks) && 
                  _available <= 525000000 && 
                  _available >= 475000000) {
         phase = FundingPhase.Phase2;
       } else {
         phase = FundingPhase.Phase3;
       }
    _;
  }
    
  modifier available() {
    require(_available > 0);
    require(block.number >= _start && block.number < _end);
    _;
  }

  modifier isToken() {
    require(msg.sender == address(_token));
    _;
  }

  modifier valid(address to, uint amount) {
    assert(amount > 0);
    amount = amount.div(_price);
    assert(_limit >= amount);
    assert(_limit >= _limits[to].add(amount));
    _;
  }

  modifier onlyWhenFinalized { 
    require(isFinalized); 
    _; 
  }
  
  modifier onlyBeforeSale { 
    require(block.timestamp < startTime); 
    _; 
  }
  
  modifier onlyWhenEnded {
    require(block.timestamp > _end || capReached);
    _;
  }  

  function TokenDistribution(address token, uint start, uint end, uint price, uint limit, uint cap, address beneficiary, address unsoldTokenBeneficiary)
      public {
      _token = Token(token);
      _start = start;
      _end = end;
      _price = price;
      _limit = limit;
      _cap = cap;
      _beneficiary = beneficiary;
      _unsoldTokenBeneficiary = unsoldTokenBeneficiary;
  }

  function ()
      public
      payable {
      // Not enough gas for the transaction so prevent users from sending ether
      revert();
  }

  function buy()
      public
      payable {
      return buyFor(msg.sender);
  }

  function buyFor(address beneficiary) 
      public      
      available 
      valid(beneficiary, msg.value)
      evalFundingPhase
      payable {
      require(msg.value > 0 && whitelist[owner] == msg.value);
      uint value = msg.value;
      uint adjustedPrice;

      if (phase == FundingPhase.Phase1) {
        // Deduct 20 percent       
        adjustedPrice = _price.sub(21740000000000);
      } else if (phase == FundingPhase.Phase2) {
        // Deduct 10 percent
        adjustedPrice = _price.sub(10870000000000);
      } else if (phase == FundingPhase.Phase3) {
        // Standard price 
        adjustedPrice = _price;
      }

      uint amount = value.div(adjustedPrice);

      collected = collected.add(value);

      _token.transfer(beneficiary, amount);
      _available = _available.sub(amount);
      _limits[beneficiary] = _limits[beneficiary].add(amount);

      Buy(beneficiary, amount, value);

      if (collected != _cap) {
        return;
      }

      GoalReached(collected);
      capReached = true;            
  }

  function tokenFallback(address, uint _value, bytes)
      isToken
      public {
      _available = _available.add(_value);
  }

  function availableBalance()
    view
    public
    returns (uint) {
    return _available;
  }

  function updateWhitelist(address[] addresses, uint256[] amounts) 
    public 
    onlyOwner {
    require(addresses.length == amounts.length);
    for (uint256 i = 0; i < addresses.length; i++) {
      whitelist[addresses[i]] = amounts[i];
    }
  }  

  function presaleAllocation(address[] investors, uint256[] tokens) 
    public 
    onlyBeforeSale 
    onlyOwner 
  {
        require(investors.length == tokens.length);

        for (uint256 i = 0; i < investors.length; i++){
            token.transfer(investors[i], tokens[i]);
            PresaleContribution(investors[i], tokens[i]);
        }
  }

  function finalize() 
    public 
    onlyWhenEnded 
    onlyOwner {
    require(!isFinalized);
    isFinalized = true;
    _beneficiary.transfer(collected);
    _token.transfer(_beneficiary, _token.balanceOf(this));
    _token.unpause();
  }

}
