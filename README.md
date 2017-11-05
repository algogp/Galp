# Galp
Trading platform written in Matlab for Interactive Brokers (IB) API

Note: Currently this only supports FX spot trading

# Introduction
This trading platform allows users to create their own trading strategies and trade with IB through its ActiveX API. The platform is written in Matlab, and the user-defined trading strategies should also be written in Matlab.

# Prerequisite
1. Matlab
2. IB Trader Workstation/Gateway
3. IB API
4. IBController (optional)

# Creating your own strategy
Each trading strategy requires at least one Signal, and exactly one Strategy. A Signal class should be derived from the SignalFactoryBase class; a Strategy class should be derived from the StrategyBase class.

See SF_CloseUpDown and Strat_BuyUpSellDown for how to create derived Signal/Strategy classes.

# What's the entry point/how do I actually use Galp?
Suppose you have already created your signal and strategy (if not, you can always use SF_CloseUpDown and Strat_BuyUpSellDown to experiment). All you have to do is to fill in the details in GalpSetup.xlsx, and then open a Matlab session and type 'Galp.start'.

# How does Galp differ from other similar projects?
The term 'trading platform' is not exactly well-defined. As a result, many projects claiming to be 'trading platforms' are in fact no more than a thin wrapper layer wrapping around the IB API to expose it to a different coding language (e.g. Matlab). I am not criticizing those projects - in fact I think a lot of them do the wrapper job very well. Galp, on the other hand, does more than that. The user can focus on creating signals and strategies, while leaving lower level tasks to Galp (e.g. talking to IB API, requesting bars, keeping track of positions, reporting PnL etc.).

# Is Galp fit for live trading?
At your own risk. It has been used for medium to low frequency strategies.
