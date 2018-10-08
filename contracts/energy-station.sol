pragma solidity ^0.4.24;
import "./bancor/utils/token-holder.sol";
import "./bancor/interfaces/bancor-formula.sol";
import "./bancor/interfaces/vet-token.sol";
import "./bancor/interfaces/vip180-token.sol";

/*
    Energy Station 

    Main contract of energy station, a simplified version of bancor converter.An implementation of relay token but no concept of smart token,
    only support the conversion across connector tokens.
    
    Open issues:
        - Front-running attacks: no need dealing with this now since no user now, let the gas price(or the proposer decide the execution order),will upgrade if it's necessary
 */
contract EnergyStation is TokenHolder{
    address public bancorFormula;                               // address of bancor formula contract
    address public vetToken;                                    // address of VET token
    address public energyToken = address(bytes6("Energy"));     // address of Energy token
    bool public conversionsEnabled = false;                     // true if token conversions is enabled, false if not
    uint32 public relayTokenWeight;                             // relay token connector weight, represented in ppm, 1-1000000, in EnergyStation weight is fixed to 500000(0.5)
    
    /**
        Constructor
    */
    constructor() public{
        relayTokenWeight = 500000;
    }

    // allows execution only when conversions aren't disabled
    modifier conversionsAllowed {
        require(conversionsEnabled, "conversion is disabled by now");
        _;
    }

    // triggered when a conversion between two tokens occurs
    event Conversion(
        address indexed _fromToken,
        address indexed _toToken,
        address indexed _trader,
        uint256 _sellAmount,
        uint256 _return,
        int256 _conversionFee
    );

    /** 
        Set bancor formula address
        @param _formula    address of a bancor formula contract
    */
    function setFormula(IBancorFormula _formula)
        public
        ownerOnly
        validAddress(_formula)
        notThis(_formula)
    {
        bancorFormula = _formula;
    }

    /** 
        Set VET Token address
        @param _vetToken    address of a vet token contract
    */
    function setVETToken(IVETToken _vetToken)
        public
        ownerOnly
        validAddress(_vetToken)
        notThis(_vetToken)
    {
        vetToken = _vetToken;
    }

    /**
        disables the entire conversion functionality
        this is a safety mechanism in case of a emergency
        can only be called by the manager

        @param _disable true to disable conversions, false to re-enable them
    */
    function disableConversions(bool _disable) public ownerOnly {
        conversionsEnabled = !_disable;
    }

    /**
        Convert Energy to VET

        @param _minReturn   if the conversion results in an amount smaller than the minimum return - it is cancelled, must be nonzero
    */
    function convertForVET(uint256 _amount, uint256 _minReturn) public returns (uint256) {
        require(IVIP180Token(energyToken).allowance(msg.sender, this) >= _amount, "Must have set allowance for this contract");

        uint256 sellAmount = _amount;
        uint256 fromConnectorBalance = IVIP180Token(energyToken).balanceOf(this);
        uint256 toConnectorBalance = IVETToken(vetToken).balanceOf(this);

        uint256 amount = IBancorFormula(bancorFormula).calculateCrossConnectorReturn(fromConnectorBalance, relayTokenWeight, toConnectorBalance, relayTokenWeight, sellAmount);

        // TODO: get final amount (amount minus conversion fee)
        uint256 feeAmount = 0;
        uint256 finalAmount = amount - feeAmount;

        // ensure the trade gives something in return and meets the minimum requested amount
        require(finalAmount != 0 && finalAmount >= _minReturn, "Invalid amount after bancor formula");

        require(finalAmount < toConnectorBalance, "Converted amount must be lower than the balance of this");

        // transfer funds from the caller in the from connector token
        require(IVIP180Token(energyToken).transferFrom(msg.sender, this, sellAmount), "Transfer energy failed");

        // transfer funds to the caller in vet
        IVETToken(vetToken).withdrawTo(msg.sender, finalAmount);
        
        // TODO: uint256 -> int256
        emit Conversion(energyToken, vetToken, msg.sender, sellAmount, finalAmount, int256(feeAmount));
        return amount;
    }

    /**
        Convert VET to Energy

        @param _minReturn   if the conversion results in an amount smaller than the minimum return - it is cancelled, must be nonzero
    */
    function convertForEnergy(uint256 _minReturn) public payable returns (uint256) {
        require(msg.value > 0, "Must have vet sent for conversion");

        // convert VET to VET Token
        IVETToken(vetToken).deposit.value(msg.value);

        uint256 sellAmount = msg.value;
        uint256 fromConnectorBalance = IVETToken(vetToken).balanceOf(this);
        uint256 toConnectorBalance = IVIP180Token(energyToken).balanceOf(this);

        uint256 amount = IBancorFormula(bancorFormula).calculateCrossConnectorReturn(fromConnectorBalance, relayTokenWeight, toConnectorBalance, relayTokenWeight, sellAmount);

        // TODO: get final amount (amount minus conversion fee)
        uint256 feeAmount = 0;
        uint256 finalAmount = amount - feeAmount;

        // ensure the trade gives something in return and meets the minimum requested amount
        require(finalAmount != 0 && finalAmount >= _minReturn, "Invalid amount after bancor formula");

        require(finalAmount < toConnectorBalance, "Converted amount must be lower than the balance of this");

        // transfer funds to the caller in the to connector token
        // the transfer might fail if the actual connector balance is smaller than the virtual balance
        require(IVIP180Token(energyToken).transfer(msg.sender, finalAmount), "Transfer energy failed");

        // TODO: uint256 -> int256
        emit Conversion(energyToken, vetToken, msg.sender, sellAmount, finalAmount, int256(feeAmount));
        return amount;
    }

}