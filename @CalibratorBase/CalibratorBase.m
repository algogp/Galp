%% Base class for a calibrator

% This is the base (virtual) class of a calibrator.

% A calibrator would, on a regular basis, receive historical data from IB
% API and re-calculate the parameters for its host strategy to use

% reqDetail is an object that has the fields: ibContract, barDuration,
% bidask, bartick, histDataLeng, reqFreq
% Formats:
% barDuration = '1 sec','5 secs','1 min','3 mins','1 hour','1 day'
% histDataLeng = '30 S','10 D','2 W','5 M','1 Y' (note: 'm' means month
% here)
% reqFreq = '30 s', '5 m', '1 h'

classdef (Abstract) CalibratorBase < handle
    methods
        % Default constructor
		function obj = CalibratorBase(hostStratHandle,reqDetailsArr)
			obj.hostStratHandle = hostStratHandle;
			obj.reqDetailsArr = reqDetailsArr;
            
            obj.dataSubscription;
        end
        
        % Tell HistDataManager what data is needed
        function dataSubscription(obj)
            myIdMap = HistDataIdMap.getInstance;
            contextSingleton = EventContext.getInstance;
            myHDMHandle = contextSingleton.myHistDataManager;
            numSubscription = length(obj.reqDetailsArr);
            for i = 1:numSubscription
                ibContract = obj.reqDetailsArr{1,i}.ibContract;
                barDuration = obj.reqDetailsArr{1,i}.barDuration;
                bidask = obj.reqDetailsArr{1,i}.bidask;
                bartick = obj.reqDetailsArr{1,i}.bartick;
                % Get id
                id = myIdMap.details2id(ibContract,barDuration,bidask,bartick);
                obj.idArr{1,i} = id;
                
                histDataLeng = obj.reqDetailsArr{1,i}.histDataLeng;
                reqFreq = obj.reqDetailsArr{1,i}.reqFreq;
                
                % Register to HistDataManager
                myHDMHandle.registerSubscription(id,histDataLeng,reqFreq);
                
                % Listen to event
                reqFreq_nospace = reqFreq(find(~isspace(reqFreq)));
                obj.signatureStrArr{1,i} = strcat('id', num2str(id), '_freq', reqFreq_nospace, '_Evt');
                handle = event.listener(myHDMHandle,'publishHistDataEvt',@obj.newDataArrives);
                obj.eventHandleArr{1,i} = handle;
                
                obj.histBarArrArr{1,i} = {};
            end
        end
        
        function newDataArrives(obj, src, dataPackage)
            disp('newDataArrives');
            % The arriving data is in the form of an array of hist data bars
            % The length of the hist data arriving might be longer than
            % what is requested
            package = dataPackage.message;
            % See if there is matching signature
            if isempty(strmatch(package.signature, obj.signatureStrArr, 'exact'))
                return;
            end
            
            histDataArr = package.data;
            % Identify which id it is
            index = find([obj.idArr{:}] == histDataArr{1,1}.id);
            % Trim histDataArr in case it is longer than requested
            reqDetails = obj.reqDetailsArr{1,index};
            originalLeng = length(histDataArr);
            trimmedLeng = min(originalLeng,DateTimeUtils.intoNumPeriod( ...
                        reqDetails.histDataLeng,reqDetails.barDuration));
            histDataArr = histDataArr(1,(originalLeng-trimmedLeng+1):end);
            % Place into histBarArrArr
            obj.histBarArrArr{1,index} = histDataArr;
            % See if all required data have arrived and if so, recalibrate
            if (~GeneralUtils.anyArrEntryEmpty(obj.histBarArrArr))
                obj.recalibrate;
                obj.flushAll;
            end
        end
        
        % Clear all data from histBarArrArr
        function flushAll(obj)
            numSubscription = length(obj.idArr);
            for i = 1:numSubscription
                obj.histBarArrArr{1,i} = {};
            end
        end
    end
    methods (Abstract)
        % This is a virtual method; to be implemented by derived class
        recalibrate(obj);
    end
    events
        
    end
    properties
        hostStratHandle
        
        idArr;
        eventHandleArr;
        reqDetailsArr;
        histBarArrArr;
        signatureStrArr;
    end
end