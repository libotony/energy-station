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

+----+          +--------------+                 +---------+
|    | ---VET-->|              | ------VET-----> |         |
|User|          |Energy-Station|                 |VET Token|
|    | <--VTHO--|              | <--VET Token--- |         |
+----+          +--------------+                 +---------+

```

### Buying VET by costing VTHO

```

+----+          +--------------+                 +---------+
|    | --VTHO-->|              | --VET Token---> |         |
|User|          |Energy-Station|                 |VET Token|
|    | <--VET---|              | <------VET----- |         |
+----+          +--------------+                 +---------+

```

## Deployment

1. Deploy `EnergyStation`, `VETToken`, `BancorFormula`
2. `EnergyStation.setVETToken(VETToken address)`
3. `EnergyStation.setFormula(BancorFormula address)`
4. `EnergyStation.setConversionFee(conversionFee in ppm)` 
5. Send VET to `EnergyStation`
6. Send VTHO to `EnergyStation`
7. Enable conversion by `EnergyStation.disableConversions(false)` 

The amount of VET and VTHO sent to `EnergyStation` will be the initial supply of two connector token.

## Usage

1. Simulate `EnergyStation.getEnergyReturn(amount)` or `EnergyStation.getVETReturn(amount)` to get converted value and multiply by 0.99 as minimum return
2. Convert VET to VTHO: `EnergyStation.convertForVET(minReturn)` 
2. Convert VTHO to VET: `Energy.approve(EnergyStation, amount)` and `EnergyStation.convertForEnergy(amount,minReturn)` 

## Web

[EnergyStationWeb Repository](https://github.com/libotony/energy-station-web)