pragma solidity ^0.4.24;
import "./builtin.sol";
/*
    Protoed is all about sponsored contract powered by vechain's account prototype model
 */

contract Protoed {

    using Builtin for Protoed;
    using Builtin for address;

    // allows execution by the owner(master-owned) only
    modifier ownerOnly {
        assert(msg.sender == this.$master());
        _;
    }

    /** 
        @return the creditPlan(credit, recoveryRate)
    */
    function creditPlan() public view returns(uint256 credit, uint256 recoveryRate) {
        return this.$creditPlan();
    }

    /**  
        set creditPlan

        @param credit original credit
        @param recoveryRate recovery rate of credit
    */
    function setCreditPlan(uint256 credit, uint256 recoveryRate) public ownerOnly {
        this.$setCreditPlan(credit, recoveryRate);
    }

    /**
        check if address 'user' is the user
        
        @param user user address
        @return bool indicates is user or not
    */
    function isUser(address user) public view returns(bool) {
        return this.$isUser(user);
    }

    /**
        return the current credit of 'user'

        @param user user address
        @return user credit
    */
    function userCredit(address user) public view returns(uint256) {
        return this.$userCredit(user);
    }

    /**
        add address 'user' to the user list

        @param user user address
    */
    function addUser(address user) public ownerOnly {
        this.$addUser(user);
    }

    /**
        remove 'user' from the user list
        
        @param user user address
    */
    function removeUser( address user) public ownerOnly {
        this.$removeUser(user);
    }

    /**
        check if 'sponsorAddress' is the sponsor of this
        
        @param sponsor sponsor address
        @return bool indicates is sponsor or not
    */
    function isSponsor(address sponsor) public view returns(bool) {
        return this.$isSponsor(sponsor);
    }

    /**
        select 'sponsorAddress' to be current selected sponsor of this
        
        @param sponsor sponsor address
    */
    function selectSponsor(address sponsor) public ownerOnly {
        this.$selectSponsor(sponsor);
    }

    /**
        return current selected sponsor
        
        @return current sponsor address
    */
    function currentSponsor() public view returns(address) {
        return this.$currentSponsor();
    }

    /**
        volunteers to be a sponsor of another account
        
        @param another account address to be sponsored
    */
    function sponsorOthers(address another) public ownerOnly {
        return another.$sponsor();
    }
 
    /**
        removes this from the sponsor candidates list of another account
        
        @param another account address to cancel sponsorship
    */
    function unsponsorOthers(address another) public ownerOnly {
        return another.$unsponsor();
    }


}