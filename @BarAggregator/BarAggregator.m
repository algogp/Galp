%% Bar Aggregator

% Since IB only provides 5s bars, this is required to supply bars with
% other (longer) durations.
% Note: Aggregated bars always fall on pre-defined time. e.g. hourly bars
% always fall on zero minute zero second of the hour, even if the trading
% system is started at e.g. 05:15:26

% TBD: IB 5s bars can also be arriving a little bit late as well as early

classdef BarAggregator < handle
    properties (Constant)
        incomingBarDuration = 5.0; % IB only provides 5s bars
        timeZoneAdj = 8; % e.g. HK is UTC+08:00 = 8
    end
    properties 
        baHandle;
        aggregatedBar; % Bar object
        barFilledCheck;
        nextPublishTime; % Date String
        id;
        barDuration
    end
    
    methods
        % Constructor
        function obj = BarAggregator(source, id, barDuration)
            % Listening to ib bar update
            handle = event.listener(source,'publishLastBarEvt',@obj.newBarArrives);
            obj.baHandle = handle;
            
            % Bar duration for aggregate bar = '10 s', '3 m', '2 h', etc.; must be multiple of 5s
            numSecond = DateTimeUtils.intoNumOfSecondWrapper(barDuration);
            obj.aggregatedBar = Bar(id,0.0,0.0,0.0,0.0,0.0,0.0,0.0,numSecond);
            
            obj.id = id;
            obj.barDuration = barDuration;
            
            obj.resetStatus;
        end

        % Publishing aggregated bar event
        function publishAggregatedBar(obj)
%             disp(obj.aggregatedBar.high);
            
            % Form message object
            msgObj.aggregatedBar = obj.aggregatedBar;
            msgObj.barFilledCheck = obj.barFilledCheck;
            msgObj.timeStamp = obj.nextPublishTime;
            % Notify other listeners
            notify(obj,'publishAggregatedBarEvt',ToggleEventData(msgObj));
            obj.resetStatus;
        end
        
        function resetStatus(obj)
            obj.aggregatedBar = Bar(obj.aggregatedBar.id, 0, 0, 0, 0, 0, 0, 0, obj.aggregatedBar.barDuration);
            
            % Calculate nextPublishTime
            % The buffer (BarAggregator.incomingBarDuration/4) is to ensure that the
            % refTimeStr input argument must be later than the
            % nextPublishTime; otherwise we run the risk of getting the new
            % nextPublishTime = old nextPublishTime
            if (~isempty(obj.nextPublishTime))
                bufferedTimeStr = DateTimeUtils.DateTimeShift(obj.nextPublishTime, ...
                                  [0,0,0,0,0,BarAggregator.incomingBarDuration/4]);
            else
                bufferedTimeStr = DateTimeUtils.DateTimeShift(datestr(clock,'yyyy-mm-dd HH:MM:SS.FFF'), ...
                                  [0,0,0,0,0,BarAggregator.incomingBarDuration/4]);
            end
            obj.nextPublishTime = DateTimeUtils.findAnchorPoint(bufferedTimeStr, obj.aggregatedBar.barDuration, 'n');
            % Set barFilledCheck zero
            obj.barFilledCheck = zeros(1,round(DateTimeUtils.intoNumOfSecond(obj.aggregatedBar.barDuration/BarAggregator.incomingBarDuration, 's')));
        end
        function updateAggBar(obj,newBar)
            % Done only when first incoming bar is received
            if sum(sum(obj.barFilledCheck) == 1)
                obj.aggregatedBar.time = newBar.time;
                obj.aggregatedBar.open = newBar.open;
                obj.aggregatedBar.high = newBar.high;
                obj.aggregatedBar.low = newBar.low;
                obj.aggregatedBar.close = newBar.close;
                obj.aggregatedBar.volume = newBar.volume;
            else
                obj.aggregatedBar.high = max(obj.aggregatedBar.high, newBar.high);
                obj.aggregatedBar.low = min(obj.aggregatedBar.low, newBar.low);
                obj.aggregatedBar.close = newBar.close;
                obj.aggregatedBar.volume = obj.aggregatedBar.volume + newBar.volume;
                % obj.aggregatedBar.wap = ; % Not implemented yet. Do
                % we have to?
            end            
        end
        function updateBarFilledCheck(obj,newBar)
            lastPublishTimeStr = DateTimeUtils.DateTimeShift(obj.nextPublishTime, [0,0,0,0,0,-obj.aggregatedBar.barDuration]);
            incBarStartTimeStr = DateTimeUtils.posix2DateTimeStr(newBar.time);
            % Round it up to 5s because IB realtime bar tends to be a bit early
            roundIncBarStartTimeStr = DateTimeUtils.findAnchorPoint(incBarStartTimeStr, 5, 'n');
            % Time zone adjustment
            adjRoundIncBarStartTimeStr = DateTimeUtils.DateTimeShift(roundIncBarStartTimeStr, [0,0,0,obj.timeZoneAdj,0,0]);
            timeRatio = DateTimeUtils.DateTimeRatio(lastPublishTimeStr,obj.nextPublishTime,adjRoundIncBarStartTimeStr);
            indexInArr = round(timeRatio*length(obj.barFilledCheck));
            obj.barFilledCheck(indexInArr+1) = 1;
        end

        function newBarArrives(obj, src, dataPackage)
            newBar = dataPackage.message;
            
            % disp([obj.aggregatedBar.open,obj.aggregatedBar.high,obj.aggregatedBar.low,obj.aggregatedBar.close] );
            % disp([newBar.open,newBar.high,newBar.low,newBar.close] );
            
            incBarStartTimeStr = DateTimeUtils.posix2DateTimeStr(newBar.time);
            % Round it up to 5s because IB realtime bar tends to be a bit early
            roundIncBarStartTimeStr = DateTimeUtils.findAnchorPoint(incBarStartTimeStr, 5, 'n');
            roundIncBarEndTimeStr = DateTimeUtils.DateTimeShift(roundIncBarStartTimeStr,[0,0,0,0,0,BarAggregator.incomingBarDuration]);
            % Time zone adjustment
            adjRoundIncBarEndTimeStr = DateTimeUtils.DateTimeShift(roundIncBarEndTimeStr, [0,0,0,obj.timeZoneAdj,0,0]);
            
            % disp([(adjRoundIncBarEndTimeStr) , (obj.nextPublishTime)]);
            
            if (datenum(adjRoundIncBarEndTimeStr) < datenum(obj.nextPublishTime))
                % case 1: incoming bar is not the last bar in the window, and it's arriving
                % normally
                % Update aggregatedBar
                obj.updateBarFilledCheck(newBar);
                obj.updateAggBar(newBar);
            elseif (datenum(adjRoundIncBarEndTimeStr) == datenum(obj.nextPublishTime))
                % case 2: incoming bar is the last bar in the window, and it's arriving
                % normally
                % Update aggregatedBar->Publish & Reset
                obj.updateBarFilledCheck(newBar);
                obj.updateAggBar(newBar);
                obj.publishAggregatedBar;
            elseif (datenum(adjRoundIncBarEndTimeStr) > datenum(obj.nextPublishTime))
                % case 3: incoming bar is the first barin the window, and the
                % previous aggregatedBar wasn't sent out because some incoming
                % bars were missing
                % Publish & Reset->Update aggregatedBar
                obj.publishAggregatedBar;
                obj.updateBarFilledCheck(newBar);
                obj.updateAggBar(newBar);
            end
%             disp([obj.aggregatedBar.open,obj.aggregatedBar.high,obj.aggregatedBar.low,obj.aggregatedBar.close] );
        end
        
    end
    events
        publishAggregatedBarEvt;
    end
end