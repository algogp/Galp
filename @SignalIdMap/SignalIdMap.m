%% Signal ID Map

% Generate and manage the unique id that is associated with a specific
% signal

classdef (Sealed) SignalIdMap < handle
    methods (Access = private)
        % Constructor
        function obj = SignalIdMap()
            
        end
        function regNewSignal(obj,newSignalName)
            arrLeng = length(obj.idArr);
            obj.signalNameArr{1,arrLeng+1} = newSignalName;
            obj.idArr{1,arrLeng+1} = arrLeng+1;
        end
    end
    methods (Static)
        function singleObj = getInstance
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = SignalIdMap;
            end
            singleObj = localObj;
        end
    end
    methods
        function [signalName] = id2details(obj, id)
            % Try to retrieve signal details using id
            % (please make sure that the id is already assigned)
            if (isempty(find(cell2mat(obj.idArr)==id,1))==1)
                % Such id doesn't exist yet
                GeneralUtils.logWrapper('SignalIdMap::id2details: No such id.');
            else
                whichCell = find(cell2mat(obj.idArr)==id,1);
                signalName = obj.signalNameArr{1,whichCell};
            end
        end
        function id = details2id(obj,signalName)
            % Retrieve existing/assign a new id
            arrLeng = length(obj.idArr);
            foundFlag = 0;
            if (arrLeng ~= 0)
                for i = 1:arrLeng
                    if (strcmp(obj.signalNameArr{1,i},signalName))
                        % Found
                        foundFlag = 1;
                        id = i;
                    end
                end
            end
            if (foundFlag == 0) || (arrLeng == 0)
                % Arrays are empty/contract details not found, assign new
                obj.regNewSignal(signalName);
                id = arrLeng+1;
            end
        end
    end
    properties
        % These arrays should always have the same length
        % The nth elements in each array belong to the same object, e.g.
        % the 3rd id corresponds to the 3rd signal name
        idArr = {}; % id, which are integers
        
        signalNameArr = {};
    end    
end