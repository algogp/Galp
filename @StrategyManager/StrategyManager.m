classdef (Sealed) StrategyManager < handle
    methods (Access = private)
        % Constructor
        function obj = StrategyManager()
            
        end
    end
    methods (Static)
        function singleObj = getInstance()
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = StrategyManager();
            end
            singleObj = localObj;
        end
    end
    methods
        function turnOnOffAllStrats(obj,onOrOff)
            numStrats = length(obj.stratArr);
            for i = 1:numStrats
                obj.stratArr{1,i}.turnOnOff(onOrOff);
            end
        end
        function registerStrat(obj,stratHandle)
            numStrats = length(obj.stratArr);
            obj.stratArr{1,numStrats+1} = stratHandle;
        end
        % Turn on or off a strat with a specific name
        function turnOnOffStrat(obj,stratName,onOrOff)
            foundFlag = 0;
            for i = 1:length(obj.stratArr)
                stratName_i = obj.stratArr{1,i}.strategyName;
                if strcmp(stratName_i,stratName)
                    foundFlag = 1;
                    obj.stratArr{1,i}.turnOnOff(onOrOff);
                    break;
                end
            end
            if foundFlag == 0
                GeneralUtils.logWrapper(['StrategyManager::turnOnOffStrat: Cannot find ' stratName]);
            end
        end
    end
    properties
        stratArr = {};
    end
end