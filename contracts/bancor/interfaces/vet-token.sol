pragma solidity ^0.4.24;
import "./vip180-token.sol";
import "./token-holder.sol";

/*
    VET Token interface
*/
contract IVETToken is ITokenHolder, IVIP180Token {
    function deposit() public payable;
    function withdraw(uint256 _amount) public;
    function withdrawTo(address _to, uint256 _amount) public;
}