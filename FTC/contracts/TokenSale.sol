pragma solidity ^0.4.17;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./TokenInterface.sol";
import "./FTCToken.sol";

contract TokenSale is Ownable {
    using SafeMath for uint;

    TokenInterface public token;

    address public beneficiary;

    uint public cap;
    uint public collected;
    uint public price;

    uint public startTime;
    uint public endTime;

    bool public capReached = false;
    bool public isFinalized = false;

    mapping (address => uint256) whitelist;

    event GoalReached(uint amountRaised);
    event NewContribution(address indexed holder, uint256 tokens, uint256 contributed);
    event PresaleContribution(address indexed holder, uint256 tokens);
    event Refunded(address indexed beneficiary, uint amount);

    modifier onlyBeforeSale { require(block.timestamp < startTime); _; }

    modifier onlyAfterSale { require(block.timestamp > endTime); _; }

    modifier onlyWhenFinalized { require(isFinalized); _; }

    modifier onlyDuringSale {
        require(block.timestamp >= startTime && block.timestamp <= endTime);
        _;
    }

    modifier onlyWhenEnded {
        require(block.timestamp > endTime || capReached);
        _;
    }

    function TokenSale(
        uint _cap,
        uint _start,
        uint _end,
        uint _tokenSupply,
        uint _price,
        address _beneficiary
    ) public
    {
        require(_end < _start + 60 days);
        cap = _cap;
        price = _price;
        token = new FTCToken(_tokenSupply);
        beneficiary = _beneficiary;

        startTime = _start;
        endTime = _end;
    }

    function () public payable {
        doPurchase(msg.sender);
    }

    function finalize() public onlyWhenEnded onlyOwner {
        require(!isFinalized);
        isFinalized = true;
        beneficiary.transfer(collected);
        token.transfer(beneficiary, token.balanceOf(this));
        token.unpause();
    }

    function doPurchase(address owner) internal onlyDuringSale {
        require(msg.value > 0 && whitelist[owner] == msg.value);
        require(collected < cap);

        uint value = msg.value;
        uint tokens = value.mul(getPrice());

        collected = collected.add(value);
        token.transfer(owner, tokens);
        NewContribution(owner, tokens, value);

        if (collected != cap) {
            return;
        }

        GoalReached(collected);
        capReached = true;
    }

    function updateWhitelist(address[] addresses, uint256[] amounts) public onlyOwner {
        require(addresses.length == amounts.length);

        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = amounts[i];
        }
    }

    function presaleAllocation(address[] investors, uint256[] tokens) public onlyBeforeSale onlyOwner {
        require(investors.length == tokens.length);

        for (uint256 i = 0; i < investors.length; i++){
            token.transfer(investors[i], tokens[i]);
            PresaleContribution(investors[i], tokens[i]);
        }
    }

    function getPrice() public view onlyDuringSale returns (uint256) {

        if (now < startTime + 7 days){
            return price.mul(100).div(125);
        }
        else if (now < startTime + 14 days){
            return price.mul(99).div(110);
        }
        else return price;

    }

}