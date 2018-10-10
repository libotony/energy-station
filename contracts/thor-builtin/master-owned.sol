pragma solidity ^0.4.24;
import "../bancor/interfaces/owned.sol";
import "./builtin.sol";

/*
    Provides support and utilities for contract ownership
    Use the concept of 'owned' but under the hood use 
    'contract master' from vechain as the storage
*/
contract Owned is IOwned {
    address public newOwner;

    using Builtin for Owned;

    event OwnerUpdate(address indexed _prevOwner, address indexed _newOwner);

    // allows execution by the owner only
    modifier ownerOnly {
        assert(msg.sender == owner());
        _;
    }

    /**
        @dev get the owner

        @return the owner
    */
    function owner() public view returns (address) {
        return this.$master();
    }

    /**
        @dev allows transferring the contract ownership
        the new owner still needs to accept the transfer
        can only be called by the contract owner

        @param _newOwner    new contract owner
    */
    function transferOwnership(address _newOwner) public ownerOnly {
        require(_newOwner != owner(), "can't transfer to current owner");
        newOwner = _newOwner;
    }

    /**
        @dev used by a new owner to accept an ownership transfer
    */
    function acceptOwnership() public {
        require(msg.sender == newOwner, "sender must be the new owner");
        emit OwnerUpdate(owner(), newOwner);
        this.$setMaster(newOwner);
        newOwner = address(0);
    }
}
