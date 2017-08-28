%% Signal Factory example: check if close price is increasing or decreasing

classdef SF_CloseUpDown < SignalFactoryBase
    methods
        % Constructor
        function obj = SF_CloseUpDown(sourceArr,barDuration,LengDataStorage,signalName)
            obj = obj@SignalFactoryBase(sourceArr,barDuration,LengDataStorage,signalName);
        end
        function newSignal = calSignal(obj)
%             disp(length(obj.barArrArr{1,1}));
            % +1 if increasing; -1 if decreasing
            if length(obj.barArrArr{1,1})== obj.LengDataStorage
                newBar = obj.barArrArr{1}{1,1};
                oldBar = obj.barArrArr{1}{1,obj.LengDataStorage};
%                 disp(newBar.close);
%                 disp(oldBar.close);
                if (newBar.close > oldBar.close)
                    newSignal = +1;
                elseif (newBar.close < oldBar.close)
                    newSignal = -1;
                else
                    newSignal = 0;
                end
            else
                newSignal = 0;
            end
        end
    end
end