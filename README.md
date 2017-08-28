# Galp
Trading platform written in Matlab for Interactive Brokers (IB) API

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
