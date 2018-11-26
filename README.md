# Energy Station

Bancor protocol powered VET/Energy(VeThor) exchange contract.

Demo page(on testnet) https://libotony.github.io/energy-station/

## Concept

The Bancor Protocol enables automatic price determination and an autonomous liquidity mechanism for tokens on smart contract blockchains. In this case，we took advantage of the automatic price adjust mechanism from bancor protocol.We use the concept of [Relay Token](https://support.bancor.network/hc/en-us/articles/360000471472-How-do-Relay-Tokens-work-) but simplified the process of buying and selling. So the concepts of `Energy Station` are:

+ Create an bancor convert contract that connecting two tokens
+ One connector token is VET, the other one is VeThor token
+ The weight of connector token is 50%
+ No smart token concept just allow the convention between VET and VeThor token

### Buying VTHO by costing VET

```

+----+          +--------------+
|    | ---VET-->|              |
|User|          |Energy-Station|
|    | <--VTHO--|              |
+----+          +--------------+

```

### Buying VET by costing VTHO

```

+----+          +--------------+
|    | --VTHO-->|              |
|User|          |Energy-Station|
|    | <--VET---|              |
+----+          +--------------+

```

## Deployment

1. Deploy `EnergyStation`
2. `EnergyStation.setConversionFee(conversionFee in ppm)`
3. Send VET by `EnergyStation.fillVET()`
4. Approve EnergyStation for VTHO token
5. Send VTHO by `EnergyStation.fillEnergy()`
6. Enable conversion by `EnergyStation.disableConversions(false)`

The amount of VET and VTHO sent to `EnergyStation` will be the initial supply of two connector token.

## Usage

1. Simulate `EnergyStation.getEnergyReturn(amount)` or `EnergyStation.getVETReturn(amount)` to get converted value and calc minimum return as `minReturn`
2. Convert VET to VTHO: `EnergyStation.convertForVET(minReturn)` 
2. Convert VTHO to VET: `Energy.approve(EnergyStation, amount)` and `EnergyStation.convertForEnergy(amount,minReturn)` 

## Web

[EnergyStationWeb Repository](https://github.com/libotony/energy-station-web)