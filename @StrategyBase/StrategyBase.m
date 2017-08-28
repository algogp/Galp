%% Base class for a trading strategy

% This is the base (virtual) class of a trading strategy.
% Note: In this project, the strategy class is only responsible for
% implementing trading logics; any calibration/signal calculation (such as
% basket spread, technical indicator, ...) should be left for signal
% factory

% A COMBO is defined as a group of contracts (all included in contractArr)
% that are traded together. Examples include a long-short basket for the
% basket spread mean reversion strategy, a call + put options for the
% volatility straddle strategy, etc.

% Note: in the most general setting, sourceArr and contractArr need not be
% the same, i.e. a strategy can listen to GOOG price to decide on trading
% SPY

classdef (Abstract) StrategyBase < handle
    methods
        % Constructor
        function obj = StrategyBase(signalArr,LengSignalStorage,contractArr,comboDefArrArr,strategyName)
            mySignalIdMap = SignalIdMap.getInstance;
            % Map signal name to id
            numSignal = length(signalArr);
            numContract = length(contractArr);
            tempIdArr = cell(1,numSignal);
            for i = 1:numSignal
                thisSignal = signalArr{1,i};
                handle = event.listener(thisSignal,'publishSignalEvt',@obj.newSignalArrives);
                obj.stratHandle{1,i} = handle;
                tempIdArr{1,i} = mySignalIdMap.details2id(thisSignal.signalName);
                obj.signalArrArr{1,i} = {};
                obj.timeStampArrArr{1,i} = {};
            end
            obj.idArr = tempIdArr;
            obj.LengSignalStorage = LengSignalStorage;
            obj.strategyName = strategyName;
            obj.contractArr = contractArr;
            obj.comboDefArrArr = comboDefArrArr;
            obj.danglingOrderFlagArr = cell(1,numContract);
            obj.danglingOrderFlagArr(1,:) = {0};
            obj.onOrOff = 1;
            % Set combo position to be zero
            obj.positionArr = cell(1,length(comboDefArrArr));
            obj.positionArr(:) = {0.0};
            
            % Register to StrategyManager
            contextSingleton = EventContext.getInstance;
            mySMHandle = contextSingleton.myStrategyManager;
            mySMHandle.registerStrat(obj);
        end
        function newSignalArrives(obj, src, dataPackage)            
            msgObj = dataPackage.message;
            % Unpack the message
            newSignal = msgObj.newSignal;
            timeStamp = msgObj.timeStamp;
            signalName = msgObj.signalName;
            % Identify id from name
            mySignalIdMap = SignalIdMap.getInstance;
            signalId = mySignalIdMap.details2id(signalName);
            % Identify index from id
            index = find([obj.idArr{:}] == signalId);
            % Update signal storage
            obj.updateDataStorage(newSignal,timeStamp,index);
            % Check if all aggBar's are received for this latest moment
            allRecFlag = obj.checkAllReceived(index);
            % Make decision/take action
            if obj.onOrOff == 1 && ... % Do only if strat is turned on
                    allRecFlag % and all signals received
                obj.orderDecision;
            end
        end
        function flag = checkAllReceived(obj, index)
            % Check if all incoming data at time T has been received
            pivotTimeStampArr = obj.timeStampArrArr{1,index};
            flag = 1;
            for i = 1:length(obj.idArr)
                thisTimeStampArr = obj.timeStampArrArr{1,i};
                if isempty(thisTimeStampArr)
                    flag = 0;
                    break
                elseif strcmp(pivotTimeStampArr{1,1},thisTimeStampArr{1,1}) == 0
                    flag = 0;
                    break
                end
            end
        end
        function updateDataStorage(obj,newSignal,timeStamp,index)
            % Updates
            % Signal
            obj.signalArrArr{1,index} = GeneralUtils.smartQueueShift(obj.signalArrArr{1,index},newSignal,obj.LengSignalStorage);
            % Time stamp
            obj.timeStampArrArr{1,index} = GeneralUtils.smartQueueShift(obj.timeStampArrArr{1,index},timeStamp,obj.LengSignalStorage);
        end
        function turnOnOff(obj,onOrOff_)
            obj.onOrOff = onOrOff_;
        end
        function placeOrderWrapper(obj,comboUnit,comboId)
            contextSingleton = EventContext.getInstance;
            myOMHandle = contextSingleton.myOrderManager;
            
            % If OrderManager has not received valid order Id yet, skip
            % action
            if myOMHandle.checkOrderIdInitialized == 0
                GeneralUtils.logWrapper('StrategyBase::placeOrderWrapper: No Order ID received yet!');
                return;
            end
            
            % Strat object should place order using this function, instead
            % of accessing OrderManager directly
            % Place order
            myOMHandle.strategyOrder(obj.strategyName, obj.contractArr, obj.comboDefArrArr{1,comboId}, comboUnit, comboId);
            % Record entered combo position locally
            obj.positionArr{1,comboId} = obj.positionArr{1,comboId} + comboUnit;
        end
        function existingPosition = getPositionWrapper(obj,comboId)
            % Strat object should get existing combo position using this function
            existingPosition = obj.positionArr{1,comboId};
        end
		% Lazy Calibrator constructor: In many cases, calibration requires the same ibContract
		% as the strategy itself, hence we provide a shorthand
		function LazyImplyCalibrator(obj, barDuraion, histDataLeng, reqFreq)
			numReq = length(hostStratHandle.contractArr);
			tempReqDetailsArr = cell(1,numReq);
			for i = 1:numReq
				tempReq.ibContract = hostStratHandle.contractArr{1,i};
				tempReq.barDuraion = barDuraion;
				tempReq.bidask = 'MIDPOINT';
				tempReq.bartick = 'bar';
				tempReq.histDataLeng = histDataLeng;
				tempReq.reqFreq = reqFreq;
				
				tempReqDetailsArr{1,i} = tempReq;
			end
			obj.myCalibrator = CalibratorBase(obj,tempReqDetailsArr);
		end
    end
    methods (Abstract)
        signalDecision(obj);
        orderDecision(obj);
    end
    events
        
    end
    properties
        stratHandle;
        strategyName;
        onOrOff = 0; % Default to be off upon construction
        
        idArr;
        signalArrArr;
        timeStampArrArr; % Array of Array to hold the sent time of incoming signals
        LengSignalStorage = 1; % By default, store only one (latest) signal
        
        contractArr; % These contracts will be ordered by this strategy
        danglingOrderFlagArr; % Whether security k has a dangling order
        
        % E.g. {{-1,1,0},{1,1,1}} means that the strategy can trade two
        % combos: short contract1+long contract2, or long all contracts
        comboDefArrArr;
        comboIdArr;
        positionArr; % Locally save the position entered
		
		myCalibrator;
    end
end