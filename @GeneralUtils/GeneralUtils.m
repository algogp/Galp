%% General Utilities

classdef GeneralUtils
    methods (Static)
        function matchOrNot = matchDeltaOneContracts(contract1,contract2)
            % contract1 and contract2 are IB contract objects
            if ((strcmp(contract1.symbol,contract2.symbol)) && ...
                (strcmp(contract1.secType,contract2.secType)) && ...
                (strcmp(contract1.exchange,contract2.exchange)) && ...
                (strcmp(contract1.currency,contract2.currency)))
                matchOrNot = 1;
            else
                matchOrNot = 0;
            end
        end
        function ibDelta1Contract = makeIbDelta1Contract(ibHandle,symbol,secType,exchange,currency,varargin)
            ibDelta1Contract = ibHandle.createContract;
            ibDelta1Contract.symbol = symbol;
            ibDelta1Contract.secType = secType;
            ibDelta1Contract.exchange = exchange;
            ibDelta1Contract.currency = currency;
        end
        function contractDetailsObj = contract2details(contract)
            outputObj.symbol = contract.symbol;
            outputObj.secType = contract.secType;
            outputObj.exchange = contract.exchange;
            outputObj.currency = contract.currency;
            
            contractDetailsObj = outputObj;
        end
        function contractDetailsArr = contractArr2detailsArr(contractArr)
            arrLeng = length(contractArr);
            for i=1:arrLeng
                outputArrTemp{1,i} = contract2details(contractArr{1,i});
            end
            contractDetailsArr = outputArrTemp;
        end
        function ibOrder = makeIbOrder(ibHandle,action,totalQuantity,orderType)
            ibOrder = ibHandle.createOrder;
            ibOrder.action = action;
            ibOrder.totalQuantity = totalQuantity;
            ibOrder.orderType = orderType;
        end
        function calibratorDetails = makeCalibratorDetails(ibContractArr,barDuraionArr, ...
                                                           bidaskArr,bartickArr, ...
                                                           histDataLengArr,reqFreqArr)
            numDetails = length(ibContractArr);
            for i = 1:numDetails
                calibratorDetails{1,i}.ibContract = ibContractArr{1,i};
                calibratorDetails{1,i}.barDuraion = barDuraionArr{1,i};
                calibratorDetails{1,i}.bidask = bidaskArr{1,i};
                calibratorDetails{1,i}.bartick = bartickArr{1,i};
                calibratorDetails{1,i}.histDataLeng = histDataLengArr{1,i};
                calibratorDetails{1,i}.reqFreq = reqFreqArr{1,i};
            end
        end
        function updatedArr = smartQueueShift(origArr,newElement,lengthCap)
            % If origArr has length < lengthCap, grow the array;
            % else, do normal queueShift
            if length(origArr) < lengthCap
                updatedArr = cell(1,length(origArr)+1);
                lengthQueue = length(origArr);
                if lengthQueue > 0
                    updatedArr(1,2:lengthQueue+1) = origArr;
                end
                updatedArr{1,1} =  newElement;
            else
                updatedArr = GeneralUtils.queueShift(origArr,newElement);
            end
        end
        function updatedArr = queueShift(origArr,newElement)
            % Treat the array as a FIFO queue, and shift everything to
            % right
            lengthQueue = length(origArr);
            updatedArr = origArr;
            if lengthQueue > 1
                updatedArr(1,2:lengthQueue) = origArr(1,1:lengthQueue-1);
            end
            updatedArr{1,1} = newElement;
        end
        function bool = anyArrEntryEmpty(myArray)
            % Check if any entry of an array is empty
            leng = length(myArray);
            bool = 0;
            for i = 1:leng
                if isempty(myArray{1,i})
                    bool = 1;
                end
            end
        end
        
        % Get vectors of open, high, low and close from array of bars
        function [openVec, highVec, lowVec, closeVec] = stripOHLCVec(barArr)
            numBar = length(barArr);
            openVec = zeros(1,numBar);
            highVec = zeros(1,numBar);
            lowVec = zeros(1,numBar);
            closeVec = zeros(1,numBar);
            for i = 1:numBar
                openVec(i) = barArr{1,i}.open;
                highVec(i) = barArr{1,i}.high;
                lowVec(i) = barArr{1,i}.low;
                closeVec(i) = barArr{1,i}.close;
            end
        end
        
        function logWrapper(msgStr)
            contextSingleton = EventContext.getInstance;
            myLMHandle = contextSingleton.myLogManager;
            myLMHandle.writeToLog(msgStr);
        end
        
        function ibExecutionFilter = makeIbExecutionFilter(ibHandle,time)
            ibExecutionFilter = ibHandle.createExecutionFilter;
            ibExecutionFilter.time = time;
        end
        
        function outputList = ibEventList()
            outputList = {'errMsg','tickSize','tickString','tickPrice', ...
                        'accountSummary','updatePortfolioEx','realtimeBar','nextValidId', ...
                        'orderStatus','updateMktDepth','updateMktDepthL2','historicalData', ...
                        'position', 'positionEnd','execDetailsEx','execDetailsEnd', ...
						'fundamentalData'};
        end
        
		function regEvents(ibHandle)
		    eventNamesArr = GeneralUtils.ibEventList();
            for i = 1:length(eventNamesArr)
                ibHandle.registerevent({eventNamesArr{i},@(varargin)ibEventHandler(varargin{:})})
            end
        end

        function reqRealTimeBarsExWrapper(ibHandle,id)
            myDataIdMap = DataIdMap.getInstance;
            [contract,barDuration,bidask,bartick] = myDataIdMap.id2details(id);
            useRTHFlag = 1;
            ibHandle.reqRealTimeBarsEx(id,contract,GeneralUtils.ibDefaultBarDuration,bidask,useRTHFlag);
        end
        
        function defaultBarDuration = ibDefaultBarDuration()
            defaultBarDuration = 5;
        end
        
        % Since we are dealing with time series, we always use one-sided
        % differencing (note: we assume that inputVec(0) has t=0,
        % inputVec(1) has t=-1 etc.
        function derivative = finiteDiffDerivative(inputVec,order)
            vecLeng = length(inputVec);
            % Error catching
            if order > vecLeng
                GeneralUtils.logWrapper('GeneralUtils::finiteDiffDerivative: Cannot compute n-th order derivative with input length < n.');
                return;
            end
            if vecLeng < 2
                GeneralUtils.logWrapper('GeneralUtils::finiteDiffDerivative: Input vector length must be >= 2.');
                return;
            elseif vecLeng > 4
                vecLeng = 4;
                GeneralUtils.logWrapper('GeneralUtils::finiteDiffDerivative: Input vector length > 4 is overridden as 4.');
            end
            % Calculate derivative
            if vecLeng == 2
                switch order
                    case 1
                        finiteDiffCoeff = [1 -1]';
                end
            elseif vecLeng == 3
                switch order
                    case 1
                        finiteDiffCoeff = [-1/2 2 -3/2]';
                    case 2
                        finiteDiffCoeff = [1 -2 1]';
                end
            elseif vecLeng == 4
                switch order
                    case 1
                        finiteDiffCoeff = [1/3 -3/2 3 -11/6]';
                    case 2
                        finiteDiffCoeff = [-1 4 -5 2]';
                    case 3
                        finiteDiffCoeff = [1 -3 3 -1]';
                end
            end
            derivative = inputVec*finiteDiffCoeff;
        end
    end
end