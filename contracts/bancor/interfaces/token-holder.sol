pragma solidity ^0.4.24;
import "./owned.sol";
import "./vip180-token.sol";

/*
    Token Holder interface
*/
contract ITokenHolder is IOwned {
    function withdrawTokens(IVIP180Token _token, address _to, uint256 _amount) public;
}
