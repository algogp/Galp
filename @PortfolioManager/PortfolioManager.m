%% Portfolio Manager

% This class is responsible for:
% - Keeping an up-to-date record of security holdings
% - Keeping an up-to-date record of strategy-based holding
% - Reconciling security holdings with IB account
% - Allow OrderManager to report new transaction
% - Provide holding info for strategies to decide on whether to trade

classdef (Sealed) PortfolioManager < handle
    methods (Access = private)
        % Constructor
        function obj = PortfolioManager(ibHandle)
            obj.myIbHandle = ibHandle;
        end
    end
    methods (Static)
        function singleObj = getInstance(ibHandle)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = PortfolioManager(ibHandle);
            end
            singleObj = localObj;
        end
    end
    methods
        function index = findIndex(obj,contract)
            % TBD: replace loop with strmatch()?
            % Find out which array index to use for a certain contract
            currentArrLeng = length(obj.mktdataContract);
            if currentArrLeng == 0
                % If the arrays have zero lenght at this point...
                index = 1;
            else
                foundFlag = 0;
                for i = 1:currentArrLeng
                    if GeneralUtils.matchDeltaOneContracts(contract,obj.mktdataContract{1,i}) == 1
                        index = i;
                        foundFlag = 1;
                    end
                end
                if foundFlag == 0
                    % Contract not among existing ones
                    index = currentArrLeng + 1;
                end
            end
        end
        function newPortfolioUpdate(obj,incomingPackage)
            % This function is called by ibEventHandler.m
            
            % contractDetail has fields:
            % conId, currency, exchange, expiry, localSymbol, primaryExchange,
            % secId, secType, strike, symbol, tradingClass
            % contractMktData has fields:
            % contract,position,marketPrice,marketValue,unrealizedPNL,realizedPNL
            contractDetail = incomingPackage{1};
            contractMktData = incomingPackage{2};
            
            contractTemp = contractMktData.contract;
            indexTemp = obj.findIndex(contractTemp);
            
            obj.detailConId{1,indexTemp} = contractDetail.conId;
            obj.detailCurrency{1,indexTemp} = contractDetail.currency;
            obj.detailExchange{1,indexTemp} = contractDetail.exchange;
            obj.detailExpiry{1,indexTemp} = contractDetail.expiry;
            obj.detailLocalSymbol{1,indexTemp} = contractDetail.localSymbol;
            obj.detailPrimaryExchange{1,indexTemp} = contractDetail.primaryExchange;
            obj.detailSecId{1,indexTemp} = contractDetail.secId;
            obj.detailSecType{1,indexTemp} = contractDetail.secType;
            obj.detailStrike{1,indexTemp} = contractDetail.strike;
            obj.detailSymbol{1,indexTemp} = contractDetail.symbol;
            obj.detailTradingClass{1,indexTemp} = contractDetail.tradingClass;
            
            obj.mktdataContract{1,indexTemp} = contractMktData.contract;
            obj.mktdataPosition{1,indexTemp} = contractMktData.position;
            obj.mktdataMarketPrice{1,indexTemp} = contractMktData.marketPrice;
            obj.mktdataMarketValue{1,indexTemp} = contractMktData.marketValue;
            obj.mktdataUnrealizedPNL{1,indexTemp} = contractMktData.unrealizedPNL;
            obj.mktdataRealizedPNL{1,indexTemp} = contractMktData.realizedPNL;
        end
        function registerContractTrade(obj,contract,position)         
            % Register completed contract trade from OrderManager
            currentArrLeng = length(obj.mktdataContractDetails_internal);
            if currentArrLeng == 0
                obj.mktdataContractDetails_internal{1,currentArrLeng+1} = GeneralUtils.contract2details(contract);
                obj.mktdataPosition_internal{1,currentArrLeng+1} = position;
            else
                foundFlag = 0;
                for i = 1:currentArrLeng
                    contractTemp = GeneralUtils.makeIbDelta1Contract(obj.myIbHandle, ...
                                    obj.mktdataContractDetails_internal{1,i}.symbol, ...
                                    obj.mktdataContractDetails_internal{1,i}.secType, ...
                                    obj.mktdataContractDetails_internal{1,i}.exchange, ...
                                    obj.mktdataContractDetails_internal{1,i}.currency);
                    if GeneralUtils.matchDeltaOneContracts(contract,contractTemp) == 1
                        obj.mktdataPosition_internal{1,i}=obj.mktdataPosition_internal{1,i} + position;
                        foundFlag = 1;
                        break
                    end
                end
                if foundFlag == 0
                    obj.mktdataContractDetails_internal{1,currentArrLeng+1} = GeneralUtils.contract2details(contract);
                    obj.mktdataPosition_internal{1,currentArrLeng+1} = position;
                end
            end
            
%             disp(obj.mktdataPosition_internal);
        end
        function position = getContractPosition(obj,contract,sourceStr)
            % Return the current position of a specific contract from ib
            % record or internal storage
            % Note: Contract is always strategy-independent
            if strcmp(sourceStr,'ib') == 1
                myContracts = obj.mktdataContract;
                myPositions = obj.mktdataPosition;
            elseif strcmp(sourceStr,'internal') == 1
                for i = 1:length(obj.mktdataContractDetails_internal)
                    myContracts{1,i} = GeneralUtils.makeIbDelta1Contract(obj.myIbHandle, ...
                        obj.mktdataContractDetails_internal{1,i}.symbol, ...
                        obj.mktdataContractDetails_internal{1,i}.secType, ...
                        obj.mktdataContractDetails_internal{1,i}.exchange, ...
                        obj.mktdataContractDetails_internal{1,i}.currency);
                end
                myPositions = obj.mktdataPosition_internal;
            end
            
            currentArrLeng = length(myContracts);
            if currentArrLeng == 0
                position = 0.0;
            else
                foundFlag = 0;
                for i = 1:currentArrLeng
                    if GeneralUtils.matchDeltaOneContracts(contract,myContracts{1,i}) == 1
                        position = myPositions{1,i};
                        foundFlag = 1;
                        break
                    end
                end
                if foundFlag == 0
                    position = 0.0;
                end
            end
        end
        function registerComboTrade(obj,strategyName,comboId,comboUnit, ...
                                    comboDef,contractArr,comboEntryPrice)
            % TBD: replace loop with strmatch()?
            
            % Register completed combo trade from OrderManager
            currentNumCombo = size(obj.ComboHolding2DArr,2);

			foundFlag = 0;
			if currentNumCombo > 0 % Search for combo only if there is more than one existing combo
				for i = 1:currentNumCombo
					if strcmp(obj.ComboHolding2DArr{1,i},strategyName) == 1 && ...
					   obj.ComboHolding2DArr{2,i} == comboId
						obj.updateComboArrays(i,comboUnit,comboEntryPrice,contractArr,0);
						foundFlag = 1;
						break
					end
				end
			end
			if foundFlag == 0
				obj.ComboHolding2DArr{1,currentNumCombo+1} = strategyName;
				obj.ComboHolding2DArr{2,currentNumCombo+1} = comboId;
				obj.stratComboDefArrArr{1,currentNumCombo+1} = comboDef;
				obj.updateComboArrays(currentNumCombo+1,comboUnit,comboEntryPrice,contractArr,1);
			end
%             disp(obj.ComboHolding2DArr(3,:));
            
            % If not added already, add new listener to price update for
            % PnL calculation
            % We only care about contract, don't care about bidask etc.,
            % therefore use getAnyIdOfContract
            for i = 1:length(contractArr)
                contract = contractArr{1,i};
                myDataIdMap = DataIdMap.getInstance;
                id = myDataIdMap.getAnyIdOfContract(contract);
                if ~isempty(id) % If such contract is found in DataIdMap
                    if isempty(obj.tickerIdArr) || ... % If not listening anything
                       isempty(find([obj.tickerIdArr{:}] == id)) % If not yet listening to this id
                        obj.listenToNew(id);
                    end
                else % If not, add it
                    myIdMap = DataIdMap.getInstance;
                    id = myIdMap.details2id(contract,'5 s','MIDPOINT','bar');
                    contextSingleton = EventContext.getInstance;
                    BA = contextSingleton.regNewBarAggregator(id);
                    ibHandle = contextSingleton.myIbHandle;
                    ibHandle.reqRealTimeBarsEx(id,contract,5,'ASK',1);
                    obj.listenToNew(id);
                end
            end
        end
		
        function updateComboArrays(obj,index,comboUnit,comboEntryPrice,contractArr,addNew)
            obj.stratContractDetailsArrArr{1,index} = GeneralUtils.contractArr2detailsArr(contractArr);
			if size(obj.ComboHolding2DArr,1) < 4 || isempty(obj.ComboHolding2DArr{4,index}) % no price info has been recorded
                obj.ComboHolding2DArr{4,index} = comboEntryPrice;
            else
				oldEntryPrice = obj.ComboHolding2DArr{4,index};
				oldHoldingDirection = sign(obj.ComboHolding2DArr{3,index});
				if obj.ComboHolding2DArr{3,index} * comboUnit < 0 % If new order and existing holding of opposite sign
					if abs(comboUnit) > abs(obj.ComboHolding2DArr{3,index})
						obj.ComboHolding2DArr{4,index} = comboEntryPrice;
					else
						% Do not update comboEntryPrice, because old position not completely consumed
					end
				else % If new order and existing holding of same sign
					% Calculate weighted entry price
					obj.ComboHolding2DArr{4,index} = (abs(obj.ComboHolding2DArr{3,index}) * obj.ComboHolding2DArr{4,index} + abs(comboUnit) * comboEntryPrice)/abs(obj.ComboHolding2DArr{3,index} + comboUnit);
				end
            end
			% Update combo holding and realized PnL
            if addNew == 1
				obj.ComboHolding2DArr{5,index} = 0.0; % No realized PnL yet
                obj.ComboHolding2DArr{3,index} = comboUnit;
            elseif addNew == 0
				% Calculate realized PnL
				if obj.ComboHolding2DArr{3,index} * comboUnit < 0 % If new order and old order of opposite sign
					positionClosed = min(abs(obj.ComboHolding2DArr{3,index}),abs(comboUnit));
				else
					positionClosed = 0.0;
				end
				obj.ComboHolding2DArr{5,index} = obj.ComboHolding2DArr{5,index} + oldHoldingDirection * positionClosed * (comboEntryPrice - oldEntryPrice);
                obj.ComboHolding2DArr{3,index} = obj.ComboHolding2DArr{3,index} + comboUnit;
            end
        end
		
        function position = getComboPosition(obj,strategyName,comboId)
            % TBD: replace loop with strmatch()?
            
            % Return the current position of a strategy-specific combo
            % Note: Combo is always defined by a strategy
            
            currentNumCombo = size(obj.ComboHolding2DArr,2);
            if currentNumCombo == 0
                position = 0.0;
            else
                foundFlag = 0;
                for i = 1:currentNumCombo
                    if strcmp(obj.ComboHolding2DArr{1,i},strategyName) == 1 && ...
                       obj.ComboHolding2DArr{2,i} == comboId
                        position = obj.ComboHolding2DArr{3,i};
                        foundFlag = 1;
                        break
                    end
                end
                if foundFlag == 0
                    position = 0.0;
                end
            end
        end

        function output = getAccountField(obj, fieldName)
            % Subscribe field from IB
            localIbHandle = obj.myIbHandle;
            localIbHandle.reqAccountSummary(501,'All',fieldName);
            
            switch fieldName
                case 'NetLiquidation'
                    output = obj.ibNetLiquidation;
                case 'TotalCashValue'
                    output = obj.ibTotalCashValue;
                case 'SettledCash'
                    output = obj.ibSettledCash;
                case 'AccruedCash'
                    output = obj.ibAccruedCash;
                case 'BuyingPower'
                    output = obj.ibBuyingPower;
                case 'EquityWithLoanValue'
                    output = obj.ibEquityWithLoanValue;
                case 'PreviousDayEquityWithLoanValue'
                    output = obj.ibPreviousDayEquityWithLoanValue;
                case 'RegTMargin'
                    output = obj.ibRegTMargin;
                case 'SMA'
                    output = obj.ibSMA;
                case 'InitMarginReq'
                    output = obj.ibInitMarginReq;
                case 'MaintMarginReq'
                    output = obj.ibMaintMarginReq;
                case 'AvailableFunds'
                    output = obj.ibAvailableFunds;
                case 'ExcessLiquidity'
                    output = obj.ibExcessLiquidity;
                case 'Cushion'
                    output = obj.ibCushion;
                case 'DayTradesRemaining'
                    output = obj.ibDayTradesRemaining;
                case 'Leverage'
                    output = obj.ibLeverage;
            end
%             % Cancel subscription
%             localIbHandle.cancelAccountSummary(501);
        end
        function output = getAccountFieldAsNum(obj, fieldName)
            outputAsStr = obj.getAccountField(fieldName);
            output = str2double(outputAsStr);
        end
        function [fieldNameArr, outputArr] = getAllAccountFields(obj)
            numFields = length(obj.accountFieldsArr);
            outputArrTemp = {};
            for i = 1:numFields
                fieldName = obj.accountFieldsArr{1,i};
                outputArrTemp{1,i} = obj.getAccountField(fieldName);
            end
            fieldNameArr = obj.accountFieldsArr;
            outputArr = outputArrTemp;
        end
        function MTM(obj)
            for i = 1:length(obj.stratContractDetailsArrArr)
                % Re-create contract array
                contractArr = {};
                for j = 1:length(obj.stratContractDetailsArrArr{1,i})
                    contractDetail = obj.stratContractDetailsArrArr{1,i}{1,j};
                    contract = GeneralUtils.makeIbDelta1Contract(obj.myIbHandle, ...
                        contractDetail.symbol, ...
                        contractDetail.secType, ...
                        contractDetail.exchange, ...
                        contractDetail.currency);
                    contractArr{1,j} = contract;
                end
                
                % Calculate new price of one unit of each combo
                priceVec = obj.gatherPrice(contractArr);
                comboDefVec = cell2mat(obj.stratComboDefArrArr{1,i});
                comboMtMPrice = comboDefVec*priceVec';
                
                % Calculate unrealized PnL
                obj.mtmArr{1,i} = obj.ComboHolding2DArr{3,i} * (comboMtMPrice - obj.ComboHolding2DArr{4,i});
                
                GeneralUtils.logWrapper(['Unrealized PnL for ' obj.ComboHolding2DArr{1,i} ':  ' num2str(obj.mtmArr{1,i})]);
            end
        end
        function priceVec = gatherPrice(obj,contractArr)
            priceVec = zeros(1,length(contractArr));
            for i = 1:length(contractArr)
                myDataIdMap = DataIdMap.getInstance;
                id = myDataIdMap.getAnyIdOfContract(contractArr{1,i});
                arrIndex = find([obj.tickerIdArr{:}] == id);
                
                contextSingleton = EventContext.getInstance;
                myFMHandle = contextSingleton.myFXManager;
                if strcmp(contractArr{1,i}.currency,myFMHandle.baseCcy)
                    priceVec(i) = obj.latestPriceArr{1,arrIndex};
                elseif strcmp(contractArr{1,i}.symbol,myFMHandle.baseCcy)
                    priceVec(i) = 1.0/obj.latestPriceArr{1,arrIndex};
                else
                    GeneralUtils.logWrapper('PortfolioManager::gatherPrice: Contract does not involve base currency');
                    return
                end
                GeneralUtils.logWrapper(['Latest ' contractArr{1,i}.symbol ' price:  ' num2str(priceVec(i))]);
            end
        end
        function reconcileIB()
            % Reconcile internal record with IB record
            % i.e. Comapre positions registered by OrderManager to IB
            % record
            
            % TBD
        end
        % Listen to price updates of new ticker
        function listenToNew(obj,id)
            arrLeng = length(obj.tickerIdArr);
            
            contextSingleton = EventContext.getInstance;
            sourceIndex = find([contextSingleton.idArr{:}] == id);
            source = contextSingleton.myEventRelaysArr{1,sourceIndex};
            
            handle = event.listener(source,'publishLastBarEvt',@obj.newBarDataArrives);
            obj.subscriptionHandleArr{1,arrLeng+1} = handle;
            obj.tickerIdArr{1,arrLeng+1} = id;
            myDataIdMap = DataIdMap.getInstance;
            [contract,barDuration,bidask,bartick] = myDataIdMap.id2details(id);
            obj.tickerContractDetailsArr{1,arrLeng+1} = GeneralUtils.contract2details(contract);
            obj.latestPriceArr{1,arrLeng+1} = [];
        end
        function newBarDataArrives(obj,src,dataPackage)
            newBar = dataPackage.message;
            arrIndex = find([obj.tickerIdArr{:}] == newBar.id);
            if length(arrIndex) > 1
                GeneralUtils.logWrapper('PortfolioManager::newBarDataArrives: Duplicated currency entries');
            end
            obj.latestPriceArr{1,arrIndex(1)} = newBar.close;
        end
        function updateSecurityHoldings(obj)
            % Reset secHoldings2DArr
            obj.secHoldings2DArr_old = obj.secHoldings2DArr_new;
            obj.secHoldings2DArr_new = {};
            
            localIbHandle = obj.myIbHandle;
            localIbHandle.reqPositions;
        end
        function updatePositions(obj,secStr,holding,secType,exchange)
            % See if already has entry
            if max(size(obj.secHoldings2DArr_new)) ~= 0
                findResult = strcmp(secStr, obj.secHoldings2DArr_new(1,:));
                if sum(findResult) > 1
                    GeneralUtils.logWrapper('PortfolioManager::updatePositions: Duplicated entries.');
                    return
                elseif sum(findResult) == 1
                    obj.secHoldings2DArr_new{2,find(findResult == 1)} = holding;
                    return
                end
            end
            
            if max(size(obj.secHoldings2DArr_new)) == 0
                newLeng = 1;
            else
                newLeng = size(obj.secHoldings2DArr_new,2) + 1;
            end
            obj.secHoldings2DArr_new{1,newLeng} = secStr;
            obj.secHoldings2DArr_new{2,newLeng} = holding;
            obj.secHoldings2DArr_new{3,newLeng} = secType;
            if strcmp(exchange,'') && strcmp(secType,'CASH')
                exchange = 'IDEALPRO';
            end
            obj.secHoldings2DArr_new{4,newLeng} = exchange;
        end
        function liqAll(obj)
            obj.flagLiqAllOrdered = 1;
            obj.updateSecurityHoldings;
        end
        function executeLiqAll(obj)
            numSecHoldings = size(obj.secHoldings2DArr_new,2);
            contextSingleton = EventContext.getInstance;
            for i = 1:numSecHoldings
                thisOrderId = contextSingleton.myOrderManager.getOrderId;
                orderAmount = -obj.secHoldings2DArr_new{2,i}; % Negative b/c we want to unwind position
                if abs(orderAmount) > 10.0 % If position too small, ignore
                    if orderAmount < 0
                        buysell = 'SELL';
                    else
                        buysell = 'BUY';
                    end
                    symbolCcyStrArr = strsplit(obj.secHoldings2DArr_new{1,i},'.');
                    symbol = symbolCcyStrArr{1};
                    secType = obj.secHoldings2DArr_new{3,i};
                    exchange = obj.secHoldings2DArr_new{4,i};
                    orderType = 'MKT'; % Must be MKT b/c we are aiming to unwind at any cost
                    currency = symbolCcyStrArr{2};
                    ibContract = GeneralUtils.makeIbDelta1Contract(obj.myIbHandle,symbol,secType,exchange,currency);
                    ibOrder=GeneralUtils.makeIbOrder(obj.myIbHandle,buysell,abs(orderAmount),orderType);
                    obj.myIbHandle.placeOrderEx(thisOrderId,ibContract,ibOrder);
                end
            end
            % Reset flag
            obj.flagLiqAllOrdered = 0;
        end
        
        function numOut = numActiveCombo(obj)
            numOut = length(obj.mtmArr);
        end
    
        function [stratName, comboId, unitHeld, entryPrice, realizedPnL, unrealizedPnL] = readCombo(obj, index)
            stratName = obj.ComboHolding2DArr{1,index};
            comboId = obj.ComboHolding2DArr{2,index};
            unitHeld = obj.ComboHolding2DArr{3,index};
            entryPrice = obj.ComboHolding2DArr{4,index};
            realizedPnL = obj.ComboHolding2DArr{5,index};
            unrealizedPnL = obj.mtmArr{1,index};
        end
        
        function numOut = numHoldingPosition(obj)
            numOut = size(obj.secHoldings2DArr_old,2);
        end
        
        function [holdingSymbol, holdingPosition] = readSec(obj, index)
            holdingSymbol = obj.secHoldings2DArr_old{1,index};
            holdingPosition = obj.secHoldings2DArr_old{2,index};
        end
    end
    
    properties
        myIbHandle;
        
        flagLiqAllOrdered = 0; % Would be set to 1 if liquidate all is ordered
        
        % These are fields that can be returned from IB reqAccountSummary directly
        accountFieldsArr = {'NetLiquidation','TotalCashValue','SettledCash','AccruedCash', ...
                       'BuyingPower','EquityWithLoanValue','PreviousDayEquityWithLoanValue','RegTMargin', ...
                       'SMA','InitMarginReq','MaintMarginReq','AvailableFunds', ...
                       'ExcessLiquidity','Cushion','DayTradesRemaining','Leverage'};

        % Not all are included, see https://www.interactivebrokers.com.hk/en/software/api/apiguide/activex/reqaccountsummary.htm
        ibNetLiquidation;
        ibTotalCashValue;
        ibSettledCash;
        ibAccruedCash;
        ibBuyingPower;
        ibEquityWithLoanValue;
        ibPreviousDayEquityWithLoanValue;
        ibRegTMargin;
        ibSMA;
        ibInitMarginReq;
        ibMaintMarginReq;
        ibAvailableFunds;
        ibExcessLiquidity;
        ibCushion;
        ibDayTradesRemaining;
        ibLeverage;
        
        % Holding fields
        % (All are arrays with length equals number of securities)
        detailConId = {};
        detailCurrency = {};
        detailExchange = {};
        detailExpiry = {};
        detailLocalSymbol = {};
        detailPrimaryExchange = {};
        detailSecId = {};
        detailSecType = {};
        detailStrike = {};
        detailSymbol = {};
        detailTradingClass = {};
        
        mktdataContract = {};
        mktdataPosition = {};
        mktdataMarketPrice = {};
        mktdataMarketValue = {};
        mktdataUnrealizedPNL = {};
        mktdataRealizedPNL = {};
        
        % Information from OrderManager
        % Contracts
        mktdataContractDetails_internal = {};
        mktdataPosition_internal = {};
        % Combos
        ComboHolding2DArr; % 1st row is strat name, 2nd row is combo Id, 3rd row is units held, 4th row is entry price; 5th row is realized PnL
        
        % Information for calculating PnL
        stratContractDetailsArrArr;
        stratComboDefArrArr;
        subscriptionHandleArr;
        tickerIdArr;
        tickerContractDetailsArr;
        latestPriceArr;
        mtmArr; % Contain marked-to-market unrealized PnL's of combos
        
        % Security holdings positions
        % First row is symbol.currency, second row is position
        % Third row is secType, fourth row is exchange
        % Since position messages take time to receive, we have an 'old'
        % array to back up the data so that we don't always wipe out the
        % info
        secHoldings2DArr_old = {};
        secHoldings2DArr_new = {};
    end
end