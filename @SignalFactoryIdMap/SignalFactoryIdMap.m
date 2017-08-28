%% Signal Factory ID Map

% Generate and manage the unique id that is associated with a specific
% signal factory
% Unlike in DataIdMap, here we make no effort in checking for duplication;
% the end user is responsible for that

classdef (Sealed) SignalFactoryIdMap < handle
    methods (Access = private)
        % Constructor
        function obj = SignalFactoryIdMap()
            
        end
    end
    methods (Static)
        function singleObj = getInstance
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = SignalFactoryIdMap;
            end
            singleObj = localObj;
        end
    end
    methods
        function id = regSignalFactory(obj, sfHandle)
            obj.counter = obj.counter + 1;
            id = obj.counter;
            obj.sfHandleArr{1,id} = sfHandle;
        end
        function sfHandle = getSfHandle(id)
            sfHandle = obj.sfHandleArr{1,id};
        end
    end
    properties
        sfHandleArr = {};
        counter = 0;
    end    
end