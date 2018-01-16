pragma solidity ^0.4.17;

import "./TokenInterface.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract Token is TokenInterface, Ownable {
    using SafeMath for uint;

    string public name;
    string public symbol;

    uint public decimals = 18;
    uint public totalSupply;

    bool public paused = false;

    mapping (address => mapping (address => uint)) allowed;
    mapping (address => uint) balances;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function Token(string _name, string _symbol, uint256 _totalSupply) public {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
    }

    function totalSupply() public view returns (uint) {
        return totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint) {
        return balances[_owner];
    }

    function allowance(address _owner, address _spender) public view returns (uint) {
        return allowed[_owner][_spender];
    }

    function transfer(address _to, uint _value) public returns (bool) {
        require(!paused || isOwner(msg.sender));

        if (_value <= 0) {
            return false;
        }

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        require(!paused || isOwner(msg.sender));
        if (_value <= 0) {
            return false;
        }

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);

        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint _value) public returns (bool) {
        require(!paused || isOwner(msg.sender));
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function unpause() public onlyOwner {
        paused = false;
    }

    function pause() public onlyOwner {
        paused = true;
    }
}
