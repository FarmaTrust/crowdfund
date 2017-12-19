pragma solidity ^0.4.17;

import "./Ownable.sol";
import "./SafeMath.sol";

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
    event Refunded(address indexed beneficiary, uint amount);

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
        address _token,
        uint _price,
        address _beneficiary
    ) public
    {
        cap = _cap;
        price = _price;
        token = TokenInterface(_token);
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
        uint tokens = value.mul(price);

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
}