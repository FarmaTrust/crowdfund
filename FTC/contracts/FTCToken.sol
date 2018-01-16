pragma solidity ^0.4.17;

import "Token.sol";

contract FTCToken is Token {

    function FTCToken(uint256 _totalSupply) public 
    Token("FarmaTrust Coin", "FTC", _totalSupply)
    {
        balances[msg.sender] = _totalSupply;
    }

}
