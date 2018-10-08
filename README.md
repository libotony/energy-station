# Energy Station

Bancor protocol powered VET/Energy(VeThor) exchange contract.

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

