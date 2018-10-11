pragma solidity ^0.4.24;
import "./bancor/utils/token-holder.sol";
import "./bancor/interfaces/bancor-formula.sol";
import "./bancor/interfaces/vet-token.sol";
import "./bancor/interfaces/vip180-token.sol";
import "./thor-builtin/protoed.sol";

/*
    Energy Station 

    Main contract of energy station, a simplified version of bancor converter.An implementation of relay token but no concept of smart token,
    only support the conversion across connector tokens.
    
    Open issues:
        - Front-running attacks: no need dealing with this now since no user now, let the gas price(or the proposer decide the execution order),will upgrade if it's necessary
 */
contract EnergyStation is TokenHolder, Protoed{
    uint64 private constant MAX_CONVERSION_FEE = 1000000;

    address public bancorFormula;                               // address of bancor formula contract
    address public vetToken;                                    // address of VET token
    address public energyToken = address(bytes6("Energy"));     // address of Energy token
    bool public conversionsEnabled = false;                     // true if token conversions is enabled, false if not
    uint32 public relayTokenWeight;                             // relay token connector weight, represented in ppm, 1-1000000, in EnergyStation weight is fixed to 500000(0.5)
    uint32 public conversionFee = 0;                            // current conversion fee, represented in ppm, 0...maxConversionFee
    
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
        uint256 _conversionFee
    );
    // triggered when the conversion fee is updated
    event ConversionFeeUpdate(uint32 _prevFee, uint32 _newFee);

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
        updates the current conversion fee
        can only be called by the owner

        @param _conversionFee new conversion fee, represented in ppm
    */
    function setConversionFee(uint32 _conversionFee)
        public
        ownerOnly
    {
        require(_conversionFee >= 0 && _conversionFee < MAX_CONVERSION_FEE, "Invalid conversion fee");
        emit ConversionFeeUpdate(conversionFee, _conversionFee);
        conversionFee = _conversionFee;
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

        @param _amount      amount to convert, in energy
        @param _minReturn   if the conversion results in an amount smaller than the minimum return - it is cancelled, must be nonzero
        @return converted amount
    */
    function convertForVET(uint256 _amount, uint256 _minReturn) 
        public 
        conversionsAllowed
        returns (uint256) 
    {
        require(IVIP180Token(energyToken).allowance(msg.sender, this) >= _amount, "Must have set allowance for this contract");

        uint256 sellAmount = _amount;
        uint256 fromConnectorBalance = IVIP180Token(energyToken).balanceOf(this);
        uint256 toConnectorBalance = IVETToken(vetToken).balanceOf(this);

        uint256 amount = IBancorFormula(bancorFormula).calculateCrossConnectorReturn(fromConnectorBalance, relayTokenWeight, toConnectorBalance, relayTokenWeight, sellAmount);

        uint256 finalAmount = getFinalAmount(amount);
        uint256 feeAmount = amount - finalAmount;

        // ensure the trade gives something in return and meets the minimum requested amount
        require(finalAmount != 0 && finalAmount >= _minReturn, "Invalid converted amount");

        require(finalAmount < toConnectorBalance, "Converted amount must be lower than the balance of this");

        // transfer funds from the caller in the from connector token
        require(IVIP180Token(energyToken).transferFrom(msg.sender, this, sellAmount), "Transfer energy failed");

        // transfer funds to the caller in vet
        IVETToken(vetToken).withdrawTo(msg.sender, finalAmount);
        
        emit Conversion(energyToken, vetToken, msg.sender, sellAmount, finalAmount, feeAmount);
        return amount;
    }

    /**
        Convert VET to Energy

        @param _minReturn   if the conversion results in an amount smaller than the minimum return - it is cancelled, must be nonzero
        @return converted amount
    */
    function convertForEnergy(uint256 _minReturn) 
        public 
        payable 
        conversionsAllowed 
        returns (uint256) 
    {
        require(msg.value > 0, "Must have vet sent for conversion");

        uint256 sellAmount = msg.value;
        uint256 fromConnectorBalance = IVETToken(vetToken).balanceOf(this);
        uint256 toConnectorBalance = IVIP180Token(energyToken).balanceOf(this);

        uint256 amount = IBancorFormula(bancorFormula).calculateCrossConnectorReturn(fromConnectorBalance, relayTokenWeight, toConnectorBalance, relayTokenWeight, sellAmount);

        uint256 finalAmount = getFinalAmount(amount);
        uint256 feeAmount = amount - finalAmount;

        // ensure the trade gives something in return and meets the minimum requested amount
        require(finalAmount != 0 && finalAmount >= _minReturn, "Invalid converted amount");

        require(finalAmount < toConnectorBalance, "Converted amount must be lower than the balance of this");

        // transfer the VET from the caller
        // convert VET to VET Token
        IVETToken(vetToken).deposit.value(msg.value)();
        
        // transfer funds to the caller in the to connector token
        // the transfer might fail if the actual connector balance is smaller than the virtual balance
        require(IVIP180Token(energyToken).transfer(msg.sender, finalAmount), "Transfer energy failed");

        emit Conversion(energyToken, vetToken, msg.sender, sellAmount, finalAmount, feeAmount);
        return amount;
    }

    /**
        get the returned energy amount that can be converted by the given VET

        @param _amount      amount to convert, in vet
        @return converted amount
     */
    function getEnergyReturn(uint256 _amount) 
        public 
        view 
        returns(uint256)
    {
        uint256 sellAmount = _amount;
        uint256 fromConnectorBalance = IVETToken(vetToken).balanceOf(this);
        uint256 toConnectorBalance = IVIP180Token(energyToken).balanceOf(this);

        uint256 amount = IBancorFormula(bancorFormula).calculateCrossConnectorReturn(fromConnectorBalance, relayTokenWeight, toConnectorBalance, relayTokenWeight, sellAmount);

        uint256 finalAmount = getFinalAmount(amount);

        require(finalAmount < toConnectorBalance, "Converted amount must be lower than the balance of this");
        return finalAmount;
    }

    /**
        get the returned vet amount that can be converted by the given energy

        @param _amount      amount to convert, in vet
        @return converted amount
     */
    function getVETReturn(uint256 _amount) 
        public 
        view 
        returns(uint256)
    {
        uint256 sellAmount = _amount;
        uint256 fromConnectorBalance = IVIP180Token(energyToken).balanceOf(this);
        uint256 toConnectorBalance = IVETToken(vetToken).balanceOf(this);

        uint256 amount = IBancorFormula(bancorFormula).calculateCrossConnectorReturn(fromConnectorBalance, relayTokenWeight, toConnectorBalance, relayTokenWeight, sellAmount);

        uint256 finalAmount = getFinalAmount(amount);

        require(finalAmount < toConnectorBalance, "Converted amount must be lower than the balance of this");
        return finalAmount;
    }

    /**
        given a return amount, returns the amount minus the conversion fee

        @param _amount      return amount

        @return return amount minus conversion fee
    */
    function getFinalAmount(uint256 _amount) public view returns (uint256) {
        return safeMul(_amount, MAX_CONVERSION_FEE - conversionFee) / MAX_CONVERSION_FEE;
    }

    /**
        deposit vet into this
    */
    function() 
        public 
        payable 
    {
         require(msg.value > 0, "Must have vet sent");
         // convert VET to VET Token
        IVETToken(vetToken).deposit.value(msg.value)();
    }
}