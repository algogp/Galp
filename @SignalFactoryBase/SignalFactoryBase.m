%% Base class for SignalFactory

% This is the base (virtual) class of a signal factory. Signal factory is
% responsible for getting data from BarAggregator and
% calculating/publishing signals

% Note: Currently we only support signals that take inputs with identical
% durations (i.e. 1m GOOG bar + 1m GS bar; 10s USDJPY bar + 10s GBPUSD bar)

classdef (Abstract) SignalFactoryBase < handle
    properties
        sfHandleArr;
        barDuration;
        minNumData; % Minimum number of data point required to cal signal
        idArr;
        barArrArr; % Array of Array to hold the incoming bars of different securities
        timeStampArrArr; % Array of Array to hold the sent time of incoming bars
        signalName;
        LengDataStorage = 1; % By default, store only one (latest) data point
    end
    methods
        % Constructor
        function obj = SignalFactoryBase(sourceArr,barDuration,LengDataStorage,signalName)
            % Listening to aggregated bar updates
            obj.barArrArr = {}; 
            numDataSource = length(sourceArr);
            for i = 1:numDataSource
                handle = event.listener(sourceArr{1,i},'publishAggregatedBarEvt',@obj.newDataArrives);
                obj.sfHandleArr{1,i} = handle;
                obj.idArr{1,i} = sourceArr{1,i}.id;
                obj.barArrArr{1,i} = {}; % Each cell is an array itself
                obj.timeStampArrArr{1,i} = {};
            end
            obj.barDuration = barDuration;
            obj.LengDataStorage = LengDataStorage;
            obj.signalName = signalName;
        end
        % Publishing signal
        function publishSignal(obj,newSignal,timeStamp)
%             disp(strcat(obj.signalName,': ',num2str(newSignal)));
            
            msgObj.newSignal = newSignal;
            msgObj.timeStamp = timeStamp;
            msgObj.signalName = obj.signalName;
            % Notify other listeners
            notify(obj,'publishSignalEvt',ToggleEventData(msgObj));
        end
        function updateDataStorage(obj,aggregatedBar,timeStamp,index)
            % Updates
            % Bar
            obj.barArrArr{1,index} = GeneralUtils.smartQueueShift(obj.barArrArr{1,index},aggregatedBar,obj.LengDataStorage);
            % Time stamp
            obj.timeStampArrArr{1,index} = GeneralUtils.smartQueueShift(obj.timeStampArrArr{1,index},timeStamp,obj.LengDataStorage);
            
            % barFilledCheck vector
            % TBD: What to do if some 5s bars have been missed when the agg bar
            % was formed?            
        end

        function newDataArrives(obj, src, dataPackage)
            msgObj = dataPackage.message;
            % Unpack the message
            aggregatedBar = msgObj.aggregatedBar;
            barFilledCheck = msgObj.barFilledCheck;
            timeStamp = msgObj.timeStamp;
            % Identify index from id
            index = find([obj.idArr{:}] == aggregatedBar.id);
            % Update data storage
            obj.updateDataStorage(aggregatedBar,timeStamp,index);
            % Check if all aggBar's are received for this latest moment
            allRecFlag = obj.checkAllReceived(index);
            % Calculate signal
            if allRecFlag
                newSignal = obj.calSignal;
                % Publish signal
                obj.publishSignal(newSignal,timeStamp);
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
    end
    methods (Abstract)
        % This is a virtual method; to be implemented by derived class
        newSignal = calSignal(obj)
    end
    events
        publishSignalEvt;
    end
end