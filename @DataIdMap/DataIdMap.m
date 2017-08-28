%% Data ID Map

% Generate and manage the unique id that is associated with a specific
% combination of {contract, bar duration, bid/ask, bar/tick}

classdef (Sealed) DataIdMap < handle
    methods (Access = private)
        % Constructor
        function obj = DataIdMap()
            
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
                localObj = DataIdMap;
            end
            singleObj = localObj;
        end
    end
    methods
        function [contract,barDuration,bidask,bartick] = id2details(obj, id)
            % Try to retrieve contract details using id
            % (please make sure that the id is already assigned)
            if (isempty(find(cell2mat(obj.idArr)==id,1))==1)
                % Such id doesn't exist yet
                GeneralUtils.logWrapper('DataIdMap::id2details: No such id.');
            else
                whichCell = find(cell2mat(obj.idArr)==id,1);
                contract = obj.contractArr{1,whichCell};
                barDuration = obj.barDurationArr{1,whichCell};
                bidask = obj.bidaskArr{1,whichCell};
                bartick = obj.bartickArr{1,whichCell};
            end
        end
        function id = getAnyIdOfContract(obj, contract)
            % Return the id that corresponds to a certain contract,
            % regardless of barDuration, bidask, bartick
            % Retrieve existing/assign a new id
            arrLeng = length(obj.idArr);
            foundFlag = 0;
            if (arrLeng ~= 0)
                for i = 1:arrLeng
                    if GeneralUtils.matchDeltaOneContracts(obj.contractArr{1,i},contract)
                        % Found
                        foundFlag = 1;
                        id = i;
                    end
                end
            end
            if (foundFlag == 0) || (arrLeng == 0)
                % Arrays are empty/contract details not found
                id = [];
                GeneralUtils.logWrapper('DataIdMap::getAnyIdOfContract: No such contract');
            end
        end
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