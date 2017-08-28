%% Order Manager

% This class is responsible for:
% - Receiving orders from strategies
% - Sending orders to IB
% - Receiving confirmation from IB
% - Registering confirmed trades with PortfolioManager
% - Keeping track of dangling (i.e. unconfirmed) orders
% Note: onlt MKT order supported now

% TBD:
% - Support STP, LMT, ...etc. order types
% - Crossing opposite orders from different strategies, if possible
% - Use native IB combo ordering (?): https://www.interactivebrokers.com.hk/en/software/api/apiguide/activex/placing_a_combination_order.htm

classdef (Sealed) OrderManager < handle
    methods (Access = private)
        % Constructor
        function obj = OrderManager(ibHandle,baseCcy)
            obj.myIbHandle = ibHandle;
            obj.baseCcy = baseCcy;
            obj.newPosFromTime = datestr(clock,'yyyymmdd-HH:MM:SS');
            ibHandle.reqIds(1);
        end
    end
    methods (Static)
        function singleObj = getInstance(ibHandle,baseCcy)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = OrderManager(ibHandle,baseCcy);
            end
            singleObj = localObj;
        end
    end
    methods
        function nextOrderId = getOrderId(obj)
            tempStore = obj.nextOrderIdStore;

            if obj.checkOrderIdInitialized == 0
                GeneralUtils.logWrapper('OrderManager::getOrderId: No Order ID received yet!');
            else
                obj.nextOrderIdStore = obj.nextOrderIdStore + 1;
            end
            nextOrderId = tempStore;
        end
        
        % Handle the orders placed by strategies
        function strategyOrder(obj, strategyName, allContractArr, comboDefArr, comboUnit, comboId)
            % - allContractArr is an array that contains all contracts of a
            % strategy (e.g. contractArr of the StrategyBase class)
            % - comboDefArr is an element of comboDefArrArr of the StrategyBase class
            % - comboUnit is a double, referring to how many unit of the
            % combo to place order on
            % - comboId is an int, e.g. strategyX may have 3 combos with id
            % = 1, 2 or 3
            
            breakFlag = 0;
            if obj.checkOrderIdInitialized == 0
                % Haven't received order id yet
                GeneralUtils.logWrapper('OrderManager::strategyOrder: No Order ID received yet!');
                breakFlag = 1;
            end
            
            if breakFlag == 0
                % Update dangling order status
                oldDOArrLeng = length(obj.strategyDOArrArr);
                newDOArrLeng = oldDOArrLeng + 1;
                
                obj.strategyDOArrArr{1,newDOArrLeng} = num2cell(cell2mat(comboDefArr));
                obj.entryPricesArrArr{1,newDOArrLeng} = num2cell(zeros(1,length(comboDefArr)));
                obj.strategyContractArrArr{1,newDOArrLeng} = allContractArr;
                obj.strategyNameArr{1,newDOArrLeng} = strategyName;
                obj.comboIdArr{1,newDOArrLeng} = comboId;
                obj.comboUnitArr{1,newDOArrLeng} = comboUnit;
                obj.comboDefArrArr{1,newDOArrLeng} = num2cell(cell2mat(comboDefArr));

                % Register the addresses to Address2DArr, and send order(s) to IB
                obj.placeOrders(allContractArr, comboDefArr, comboUnit, ...
                                newDOArrLeng, strategyName, comboId);
            end
        end
        
        % Register the addresses to Address2DArr, and send order(s) to IB
        % (Refuse to place order for fx pairs that do not involve base ccy, e.g.
        % EUR.JPY)
        function placeOrders(obj, allContractArr, comboDefArr, comboUnit, ...
                             DOArrArrColIndex, strategyName, comboId)
            numContract = length(allContractArr);

            for conCount = 1:numContract
                % Refuse to place order for fx pairs that do not involve
                % base ccy
                if obj.isBaseCcyInvolved(allContractArr{1,conCount}) == 0
                    GeneralUtils.logWrapper('OrderManager::placeOrder: Contract does not involve base currency');
                    break
                end
                if comboDefArr{1,conCount} ~= 0
                    thisOrderId = obj.getOrderId;

                    % Register the addresses to Address2DArr
                    obj.registerAddress(thisOrderId, conCount, DOArrArrColIndex);
                    
                    % Check if fx inversion is required and adjust order
                    % amount accordingly
                    adjFactor = obj.getAdjFactor(allContractArr{1,conCount});
                    
                    % Send order(s) to IB
                    orderAmount = adjFactor*comboDefArr{1,conCount}*comboUnit;
                    if orderAmount < 0
                        buysell = 'SELL';
                    else
                        buysell = 'BUY';
                    end
                    ibOrder=GeneralUtils.makeIbOrder(obj.myIbHandle,buysell,abs(orderAmount),'MKT'); % Hardcoded to be 'MKT'
                    obj.myIbHandle.placeOrderEx(thisOrderId,allContractArr{1,conCount},ibOrder);

                    % Store order Id
                    numOutOrder = length(obj.outstandingOrderIdArr);
                    obj.outstandingOrderIdArr{1,numOutOrder+1} = thisOrderId;
                end
            end
            GeneralUtils.logWrapper(['Order ' num2str(thisOrderId) ' placed: ' ...
                                     strategyName ' Combo ' num2str(comboId) ...
                                     ' Amount: ' num2str(comboUnit)]);
        end
        
        % Check if base currency is involved in a contract
        function trueFalse = isBaseCcyInvolved(obj,contract)
            if (strcmp(contract.symbol,obj.baseCcy)==0) && ...
               (strcmp(contract.currency,obj.baseCcy)==0)
                trueFalse = 0;
            else
                trueFalse = 1;
            end
        end
        
        % Get amount adjustment factor (for USD.XXX pair)
        function adjFactor = getAdjFactor(obj,contract)
            if strcmp(contract.currency,obj.baseCcy)==0
                contextSingleton = EventContext.getInstance;
                myFMHandle = contextSingleton.myFXManager;
                % negative because buy USD.XXX becomes sell
                % XXX.USD, vice versa
                adjFactor = -1.0/myFMHandle.getLatestPrice(contract.currency);
            else
                adjFactor = 1.0;
            end
        end
        
        % When new order status is received from IB
        function newOrderStatusUpdate(obj, orderId, avgFillPrice, status)         
            if strcmp(status,'Filled')
                % Register leg with PortfolioManager

                if isempty(find([obj.outstandingOrderIdArr{:}] == orderId,1))
                    % Probably receiving order status update after it is
                    % already completely filled; do nothing
%                     disp('OrderManager::newOrderStatusUpdate: Useless update');
                    GeneralUtils.logWrapper('OrderManager::newOrderStatusUpdate: Filled but not recognized.');
                    return;
                end
                
                [whichLeg, whichCombo] = obj.getAddress(orderId);
                
                if sum(abs(cell2mat(obj.strategyDOArrArr{1,whichCombo}))) == 0
                    % All legs in the combo already filled
                    GeneralUtils.logWrapper('OrderManager::newOrderStatusUpdate: All legs in combo filled already.');
                    return;
                end
                
                % Update dangling order status
                filledAmount = obj.updateDanglingStatusToZero(orderId);

                % Record leg entry price
                obj.recordLegEntryPrice(orderId,avgFillPrice);

                contextSingleton = EventContext.getInstance;
                myPMHandle = contextSingleton.myPortfolioManager;
                myPMHandle.registerContractTrade(obj.strategyContractArrArr{1,whichCombo}{1,whichLeg},filledAmount*obj.comboUnitArr{1,whichCombo});

                % Update outstandingOrderIdArr
                orderIdIndex = find([obj.outstandingOrderIdArr{:}] == orderId);
                obj.outstandingOrderIdArr(:,orderIdIndex) = [];

                % Cancel completely filled order
%                     obj.myIbHandle.cancelOrder(orderId);

                % Check if all legs in the combo are filled; if so, update all
                % relevant arrays, and report to PorfolioManager
                if sum(abs(cell2mat(obj.strategyDOArrArr{1,whichCombo}))) == 0
                    % Calculate combo entry price
                    entryPriceVec = cell2mat(obj.entryPricesArrArr{1,whichCombo});
                    comboDefVec = cell2mat(obj.comboDefArrArr{1,whichCombo});
                    comboEntryPrice = comboDefVec*entryPriceVec';

                    GeneralUtils.logWrapper(['Strat ' obj.strategyNameArr{1,whichCombo} ...
                                            ' Combo ' num2str(obj.comboIdArr{1,whichCombo}) ...
                                            ' entried at ' num2str(comboEntryPrice)]);

                    % Register with PortfolioManager
                    myPMHandle.registerComboTrade(obj.strategyNameArr{1,whichCombo}, ...
                                           obj.comboIdArr{1,whichCombo}, ...
                                           obj.comboUnitArr{1,whichCombo}, ...
                                           obj.comboDefArrArr{1,whichCombo}, ...
                                           obj.strategyContractArrArr{1,whichCombo}, ...
                                           comboEntryPrice)

%                     obj.updateCombo(whichCombo);
                end
%                 disp(cell2mat(obj.outstandingOrderIdArr));
            end
        end
        function filledAmount = updateDanglingStatusToZero(obj,orderId)
            % Find address
            [whichLeg, whichCombo] = obj.getAddress(orderId);
            
            filledAmount = obj.strategyDOArrArr{1,whichCombo}{1,whichLeg};
            % Update strategyDOArrArr
            obj.strategyDOArrArr{1,whichCombo}{1,whichLeg} = 0;
        end
        function recordLegEntryPrice(obj,orderId,avgFillPrice)
            % Find address
            [whichLeg, whichCombo] = obj.getAddress(orderId);
            
            % Check if fx inversion required
            contract = obj.strategyContractArrArr{1,whichCombo}{1,whichLeg};
            if obj.getAdjFactor(contract)==1.0
                % If getAdjFactor returns 1, we are dealing with XXX.USD
                obj.entryPricesArrArr{1,whichCombo}{1,whichLeg} = avgFillPrice;
            else
                % If not, we are dealing with USD.XXX
                obj.entryPricesArrArr{1,whichCombo}{1,whichLeg} = 1.0/avgFillPrice;
            end
        end
        function updateCombo(obj, whichCombo)
            % Update member arrays
            obj.strategyDOArrArr(:,whichCombo) = [];
            obj.entryPricesArrArr(:,whichCombo) = [];
            obj.strategyContractArrArr(:,whichCombo) = [];
            obj.strategyNameArr(:,whichCombo) = [];
            obj.comboIdArr(:,whichCombo) = [];
            obj.comboUnitArr(:,whichCombo) = [];
            obj.comboDefArrArr(:,whichCombo) = [];
        end
        function registerAddress(obj, orderId, whichLeg, whichCombo)
            oldNumAddress = size(obj.Address2DArr,2);
            
            obj.Address2DArr{1,oldNumAddress+1} = orderId;
            obj.Address2DArr{2,oldNumAddress+1} = whichLeg;
            obj.Address2DArr{3,oldNumAddress+1} = whichCombo;
        end
        function [whichLeg, whichCombo] = getAddress(obj, orderId)
            colOfAddress2DArr = find([obj.Address2DArr{1,:}] == orderId);
            whichLeg = obj.Address2DArr{2,colOfAddress2DArr};
            whichCombo = obj.Address2DArr{3,colOfAddress2DArr};
        end
        % Check if a specific strategy combo has dangling orders (mainly
        % used by a strategy to check if new order should be placed)
        function trueFalse = anyDangling(obj,strategyName,comboId)
            % Loop through the length of strategyNameArr/comboIdArr to see
            % if at any index there is a match on both
            numOutstandingCombo = length(obj.strategyNameArr);
            trueFalse = 0;
            % If numOutstandingCombo empty then there must be nothing
            % dangling
            if numOutstandingCombo > 0
                for comCount = 1:numOutstandingCombo
                    if (strcmp(strategyName,obj.strategyNameArr{1,comCount}) == 1) && ...
                       (comboId == obj.comboIdArr{1,comCount})
                        trueFalse = 1;
                        break
                    end
                end
            end
        end
        
        function checkOrderCompletion(obj)
            % Update newPosFromTime: In the next execution, check only
            % after this moment
            % We allow for a 5min buffer time
            obj.newPosFromTime = datestr(DateTimeUtils.DateTimeShift(datestr(clock,'yyyy-mm-dd-HH:MM:SS'),[0,0,0,0,-5,0]),'yyyymmdd-HH:MM:SS');
            
            execFilter = GeneralUtils.makeIbExecutionFilter(obj.myIbHandle,obj.newPosFromTime);
            obj.myIbHandle.reqExecutionsEx(1,execFilter);
        end
        
        function flag = checkOrderIdInitialized(obj)
            if obj.nextOrderIdStore < 0
                % Re-request if not initialized
                obj.myIbHandle.reqIds(1);
                flag = 0;
            else
                flag = 1;
            end
        end
    end
    properties
        myIbHandle;
        baseCcy = 'USD';
        initialOrderId; % First order id that is valid (i.e. unused)
        
        outstandingOrderIdArr;
        
        strategyNameArr; % Could have duplicated values, in case one strat trades multiple combos
        comboIdArr;
        comboUnitArr;
        comboDefArrArr;
        % If the k-th entry of strategyNameArr is 'strategyX', then the
        % k-th entry of strategyDOArrArr is an array of order positions, of the
        % length = allContractArr for 'strategyX'
        strategyDOArrArr; % Keeping track of dangling orders
        entryPricesArrArr;
        strategyContractArrArr;
        
        nextOrderIdStore = -1; % Default to be negative to indicate not set
        
        % Address2DArr helps matching id order to location of the order
        % within strategyDOArrArr.
        % - Each column represents info of one order
        % - First row of Address2DArr is the order id
        % - Second row is which leg of a combo to find the order
        % - Third row is which combo of strategyDOArrArr to find the order
        Address2DArr;
        
        % newPosFromTime is a time string in the format of
        % 'yyyymmdd HH:MM:SS' that marks when we should set filter for
        % reqExecutionsEx(). This is updated automatically in every timer
        % cycle
        newPosFromTime = '';
    end
end