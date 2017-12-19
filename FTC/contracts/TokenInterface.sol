pragma solidity ^0.4.17;

contract TokenInterface {
    function balanceOf(address _owner) public view returns (uint);
    function transfer(address _to, uint _value) public returns (bool);
    function unpause() public;
}
