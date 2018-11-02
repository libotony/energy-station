pragma solidity ^0.4.24;
import "./thor-builtin/protoed.sol";
import "./interfaces/vip180-token.sol";
import "./utils.sol";
import "./thor-builtin/master-owned.sol";

/*
    Energy Station 

    Main contract of energy station, a simplified version of bancor converter.An implementation of relay token but no concept of smart token,
    only support the conversion across connector tokens.
    
    Open issues:
        - Front-running attacks: no need dealing with this now since no user now, let the gas price(or the proposer decide the execution order),will upgrade if it's necessary
 */
contract EnergyStation is Utils, Owned, Protoed{
    uint64 private constant MAX_CONVERSION_FEE = 1000000;

    address public energyToken = address(bytes6("Energy"));     // address of Energy token
    uint32 public conversionFee = 0;                            // current conversion fee, represented in ppm, 0...maxConversionFee
    bool public conversionsEnabled = false;                     // true if token conversions is enabled, false if not
    uint104 public vetVirtualBalance = 0;                       // virtual balance represents the current vet balance(uint104 represents 2e31 that is greater than 87b vet)
    uint256 public energyVirtualBalance = 0;                    // virtual balance represents the current energy balance
    
    /**
        Constructor
    */
    constructor() public{
    }

    // allows execution only when conversions aren't disabled
    modifier conversionsAllowed {
        require(conversionsEnabled, "conversion is disabled by now");
        _;
    }

    // triggered when a conversion between two tokens occurs
    event Conversion(
        int8 indexed tradeType,   // 0 - vet -> energy, 1- energy -> vet
        address indexed _trader,
        uint256 _sellAmount,
        uint256 _return,
        uint256 _conversionFee
    );
    // triggered when the conversion fee is updated
    event ConversionFeeUpdate(uint32 _prevFee, uint32 _newFee);

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
        change the entire conversion status functionality
        this is a safety mechanism in case of a emergency
        can only be called by the owner

        @param _disable true to disable conversions, false to re-enable them
    */
    function changeConversionStatus(bool _enabled) public ownerOnly {
        conversionsEnabled = _enabled;
    }

    /**
        Convert Energy to VET

        @param _sellAmount      amount to convert, in energy
        @param _minReturn   if the conversion results in an amount smaller than the minimum return - it is cancelled, must be nonzero
        @return converted amount
    */
    function convertForVET(uint256 _sellAmount, uint256 _minReturn) 
        public 
        conversionsAllowed
        returns (uint256) 
    {
        require(IVIP180Token(energyToken).allowance(msg.sender, this) >= _sellAmount, "Must have set allowance for this contract");

        uint256 amount = calculateCrossConnectorReturn(energyVirtualBalance, vetVirtualBalance, _sellAmount);

        uint256 finalAmount = getFinalAmount(amount);
        uint256 feeAmount = amount - finalAmount;

        // ensure the trade gives something in return and meets the minimum requested amount
        require(finalAmount != 0 && finalAmount >= _minReturn, "Invalid converted amount");

        require(finalAmount < vetVirtualBalance, "Converted amount must be lower than the balance of this");

        // transfer funds from the caller in the from connector token
        require(IVIP180Token(energyToken).transferFrom(msg.sender, this, _sellAmount), "Transfer energy failed");

        // transfer funds to the caller in vet
        msg.sender.transfer(finalAmount);
        
        emit Conversion(1, msg.sender, _sellAmount, finalAmount, feeAmount);
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

        uint256 _sellAmount = msg.value;
        uint256 toConnectorBalance = IVIP180Token(energyToken).balanceOf(this);

        uint256 amount = calculateCrossConnectorReturn(vetVirtualBalance, energyVirtualBalance, _sellAmount);

        uint256 finalAmount = getFinalAmount(amount);
        uint256 feeAmount = amount - finalAmount;

        // ensure the trade gives something in return and meets the minimum requested amount
        require(finalAmount != 0 && finalAmount >= _minReturn, "Invalid converted amount");

        require(finalAmount < toConnectorBalance, "Converted amount must be lower than the balance of this");
        
        // transfer funds to the caller in the to connector token
        // the transfer might fail if the actual connector balance is smaller than the virtual balance
        require(IVIP180Token(energyToken).transfer(msg.sender, finalAmount), "Transfer energy failed");

        emit Conversion(0, msg.sender, _sellAmount, finalAmount, feeAmount);
        return amount;
    }

    /**
        get the returned energy amount that can be converted by the given VET

        @param _sellAmount      amount to convert, in vet
        @return converted amount
     */
    function getEnergyReturn(uint256 _sellAmount) 
        public 
        view 
        returns(uint256 canAcquire)
    {
        require(_sellAmount > 0, "Must have amount set for conversion");

        uint256 amount = calculateCrossConnectorReturn(vetVirtualBalance, energyVirtualBalance, _sellAmount);
        canAcquire = getFinalAmount(amount);

        require(canAcquire < energyVirtualBalance, "Converted amount must be lower than the balance of this");
    }

    /**
        get the returned vet amount that can be converted by the given energy

        @param _sellAmount      amount to convert, in vet
        @return converted amount
     */
    function getVETReturn(uint256 _sellAmount) 
        public 
        view 
        returns(uint256 canAcquire)
    {
        require(_sellAmount > 0, "Must have amount set for conversion");

        uint256 amount = calculateCrossConnectorReturn(energyVirtualBalance, vetVirtualBalance, _sellAmount);
        canAcquire = getFinalAmount(amount);

        require(canAcquire < vetVirtualBalance, "Converted amount must be lower than the balance of this");
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
        From Bancor at tag v0.4.2
        given two connector balances(both weight are 0.5 for this case) and a sell amount (in the first connector token),
        calculates the return for a conversion from the first connector token to the second connector token (in the second connector token)

        Original Formula:
        Return = _toConnectorBalance * (1 - (_fromConnectorBalance / (_fromConnectorBalance + _amount)) ^ (_fromConnectorWeight / _toConnectorWeight))

        Simplified Formula:
        Return = _toConnectorBalance * (1 - (_fromConnectorBalance / (_fromConnectorBalance + _amount)))

        @param _fromConnectorBalance    input connector balance
        @param _toConnectorBalance      output connector balance
        @param _amount                  input connector amount

        @return second connector amount
    */
    function calculateCrossConnectorReturn(uint256 _fromConnectorBalance, uint256 _toConnectorBalance, uint256 _amount) private pure returns (uint256) {
        // validate input
        require(_fromConnectorBalance > 0 && _toConnectorBalance > 0);
        return safeMul(_toConnectorBalance, _amount) / safeAdd(_fromConnectorBalance, _amount);
    }
}