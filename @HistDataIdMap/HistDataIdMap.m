%% Hist Data ID Map

% Generate and manage the unique id that is associated with a specific
% combination of {contract, bar duration, bid/ask, bar/tick} for historical
% data retrieving

classdef (Sealed) HistDataIdMap < handle
    methods (Access = private)
        % Constructor
        function obj = HistDataIdMap()
            
        end
        function regNewContractDetails(obj, contract, barDuration, bidask, bartick)
            arrLeng = length(obj.idArr);
            obj.contractArr{1,arrLeng+1} = contract;
            obj.barDurationArr{1,arrLeng+1} = barDuration;
            obj.bidaskArr{1,arrLeng+1} = bidask;
            obj.bartickArr{1,arrLeng+1} = bartick;
            obj.idArr{1,arrLeng+1} = arrLeng+1;
        end
    end
    methods (Static)
        function singleObj = getInstance
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = HistDataIdMap;
            end
            singleObj = localObj;
        end
    end
    methods
        function id = details2id(obj, contract, barDuration, bidask, bartick)
            % Retrieve existing/assign a new id
            arrLeng = length(obj.idArr);
            foundFlag = 0;
            if (arrLeng ~= 0)
                for i = 1:arrLeng
                    if ((GeneralUtils.matchDeltaOneContracts(obj.contractArr{1,i},contract)) & ...
                        strcmp(obj.barDurationArr{1,i}, barDuration) & ...
                        strcmp(obj.bidaskArr{1,i}, bidask) & ...
                        strcmp(obj.bartickArr{1,i}, bartick))
                        % Found
                        foundFlag = 1;
                        id = i;
                    end
                end
            end
            if (foundFlag == 0) || (arrLeng == 0)
                % Arrays are empty/contract details not found, assign new
                obj.regNewContractDetails(contract, barDuration, bidask, bartick);
                id = arrLeng+1;
            end
        end
    end
    properties
        % These arrays should always have the same length
        % The nth elements in each array belong to the same object, e.g.
        % the 3rd id corresponds to the 3rd contract with the 3rd bidask
        % and bartick
        idArr = {}; % id, which are integers
        
        contractArr = {}; % IB contract objects
        barDurationArr = {}; % Bar duration (e.g. '10 s', '3 m', '2 h', etc.)
        bidaskArr = {}; % 'bid' or 'ask' (only meaningful for bar)
        bartickArr = {}; % 'bar' or 'tick'
    end    
end