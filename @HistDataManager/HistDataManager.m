%% Historical Data Manager

% This class is responsible for:
% - Keeping track of which Calibrator object needs what data
% - Subscribing to and receiving historical data from IB API
% - Delivering the right data package to the right recipient regularly

classdef (Sealed) HistDataManager < handle
    methods (Access = private)
        % Constructor
        function obj = HistDataManager(ibHandle)
            obj.myIbHandle = ibHandle;
        end
    end
    methods (Static)
        function singleObj = getInstance(ibHandle)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = HistDataManager(ibHandle);
            end
            singleObj = localObj;
        end
    end
    methods
        % Called by Calibrator
        function registerSubscription(obj,id,histDataLeng,reqFreq)
            existingLeng = length(obj.idArr);
            
            obj.idArr{1,1+existingLeng} = id;
            obj.histDataLengArr{1,1+existingLeng} = histDataLeng;
            obj.reqFreqArr{1,1+existingLeng} = reqFreq;
            
            obj.fillULDArrays(id,histDataLeng,reqFreq);
            obj.fillReqFreqArrArr;
        end
        
        function fillReqFreqArrArr(obj)
            % This should be called only after all other setup steps are
            % done; in particular, this should be called after fillULDArrays
            for i = 1:length(obj.idArr)
                idReqFreqStr = obj.reqFreqArr{1,i};
                idIndexOnUnique = find([obj.idArr_unique{:}] == obj.idArr{1,i}, 1);
                if idIndexOnUnique > length(obj.reqFreqArrArr)
                    reqFreqArrTemp = {};
                    reqFreqMultipleArrTemp = {};
                else
                    reqFreqArrTemp = obj.reqFreqArrArr{1,idIndexOnUnique};
                    reqFreqMultipleArrTemp = obj.reqFreqMultipleArrArr{1,idIndexOnUnique};
                end
                
                if isempty(strmatch(idReqFreqStr, reqFreqArrTemp, 'exact'))
                    reqFreqArrLeng = length(reqFreqArrTemp);
                    reqFreqArrTemp{1,reqFreqArrLeng + 1} = idReqFreqStr;
                    obj.reqFreqArrArr{1,idIndexOnUnique} = reqFreqArrTemp;
                    
                    % What multiple times the densest reqFreq is this reqFreq?
                    % id's request frequency in second
                    idReqFreq = DateTimeUtils.intoNumOfSecondWrapper(idReqFreqStr);
                    % String of densest request frequency
                    denseFreqStr = obj.reqFreqArr_densest{1,idIndexOnUnique};
                    % Densest request frequency in second
                    denseFreq = DateTimeUtils.intoNumOfSecondWrapper(denseFreqStr);
                    multiple = idReqFreq/denseFreq;
                    if multiple < 1.0
                        GeneralUtils.logWrapper('HistDataManager::fillReqFreqArrArr: reqFreqArr_densest not the shortest');
                    end
                    reqFreqMultipleArrTemp{1,reqFreqArrLeng + 1} = multiple;
                    obj.reqFreqMultipleArrArr{1,idIndexOnUnique} = reqFreqMultipleArrTemp;
                end
            end
        end
                
        % Fill the unique/longest/densent arrays
        function fillULDArrays(obj,id,histDataLeng,reqFreq)
            % Do we have the id in idArr_unique already?
            if isempty(obj.idArr_unique) || ...
               isempty(find([obj.idArr_unique{:}] == id, 1))
                % If not
                arrLeng = length(obj.idArr_unique);
                
                obj.idArr_unique{1,arrLeng+1} = id;
                obj.histDataLengArr_longest{1,arrLeng+1} = histDataLeng;
                obj.reqFreqArr_densest{1,arrLeng+1} = reqFreq;
            else
                % If so
                index = find([obj.idArr_unique{:}] == id);
                if DateTimeUtils.intoNumOfSecondWrapper(histDataLeng) ...
                        > DateTimeUtils.intoNumOfSecondWrapper(obj.histDataLengArr_longest{1,index})
                    obj.histDataLengArr_longest{1,index} = histDataLeng;
                end
                if DateTimeUtils.intoNumOfSecondWrapper(reqFreq) ...
                        < DateTimeUtils.intoNumOfSecondWrapper(obj.reqFreqArr_densest{1,index})
                    obj.reqFreqArr_densest{1,index} = reqFreq;
                end
            end
            % Fill the counterArr
            for i = 1:length(obj.idArr_unique)
                obj.counterArr{1,i} = 0;
            end
        end
        
        % This is called externally <<WHEN ALL CALIBRATORS HAVE BEEN
        % REGISTERED>>
        function startTiming(obj)
            % Create timers as needed
            for i = 1:length(obj.idArr_unique)
                periodInSecond = DateTimeUtils.intoNumOfSecondWrapper(obj.reqFreqArr_densest{1,i});
                histDataLengStr = obj.histDataLengArr_longest{1,i};
                myTimer = timer('BusyMode','drop', ...
                                'StartDelay',60, ...
                                'Period',periodInSecond, ...
                                'TimerFcn',{@timerCallback.TCB_reqHistData, obj.idArr_unique{1,i}, histDataLengStr}, ...
                                'ErrorFcn',@(~,~) GeneralUtils.logWrapper(strcat('Timer error in HistDataManager id ',num2str(obj.idArr_unique{1,i}))), ...
                                'ExecutionMode','fixedDelay');
                start(myTimer);
                obj.timerHandleArr{1,i} = myTimer;
                obj.flushId(obj.idArr_unique{1,i});
            end
        end
        
        function flushId(obj,id)
            index = find([obj.idArr_unique{:}] == id,1);
            obj.histBarArrArr{1,index} = {};
        end
        
        function flushAll(obj)
            numId = length(obj.idArr_unique);
            for i = 1:numId
                obj.histBarArrArr{1,i} = {};
            end
        end
        
        function receiveNewBar(obj,newBar)
%             disp('receiveNewBar');
            % Note: After all the data is delivered there will be an extra
            % notification sent, with the bar time string being "finished-<start
            % time>-<end time>" and all other fields = -1
        
            if (~strcmp(newBar.time(1:8),'finished'))
                % Fill histBarArrArr
                if isempty(find([obj.idArr_unique{:}] == newBar.id,1))
                    GeneralUtils.logWrapper('HistDataManager::receiveNewBar: No such id.');
                else
                    index = find([obj.idArr_unique{:}] == newBar.id);
                    lengOld = length(obj.histBarArrArr{1,index});
                    obj.histBarArrArr{1,index}{1,lengOld+1} = newBar;
                end
            else
                % Publish
                obj.publishToCalibrators(newBar.id);
                obj.flushId(newBar.id);
            end
%             disp(newBar.time);
%             disp(newBar.close);
        end
        
        function publishToCalibrators(obj,id)
            disp('publishToCalibrators');
            indexOnUnique = find([obj.idArr_unique{:}] == id);
            % Add one to the counter on this index
            obj.counterArr{1,indexOnUnique} = obj.counterArr{1,indexOnUnique} + 1;
            dataArrayTemp = obj.histBarArrArr{1,indexOnUnique};
            reqFreqArrTemp = obj.reqFreqArrArr{1,indexOnUnique};
            reqFreqMultipleArrTemp = obj.reqFreqMultipleArrArr{1,indexOnUnique};
            
            % Loop and check which reqFreq needs publishing
            for i = 1:length(reqFreqArrTemp)
                multiple = reqFreqMultipleArrTemp{1,i};
                
                % If needs publishing...
                if mod(obj.counterArr{1,indexOnUnique},multiple) == 0
                    % Form the event name string
                    reqFreqArrTempi = reqFreqArrTemp{1,i};
                    reqFreqArrTempi_nospace = reqFreqArrTempi(find(~isspace(reqFreqArrTempi)));
                    signatureStr = strcat('id', num2str(id), '_freq', reqFreqArrTempi_nospace, '_Evt');
                    % Publish the corresponding array to the calibrators
                    package.signature = signatureStr;
                    package.data = dataArrayTemp;
                    notify(obj,'publishHistDataEvt',ToggleEventData(package));
                end
            end
        end
    end
    properties
        myIbHandle;
        timerHandleArr;
        
        idArr;
        histDataLengArr;
        reqFreqArr;
        
        idArr_unique;
        histDataLengArr_longest; % Stored as string (e.g. '1 W')
        reqFreqArr_densest; % Stored as string (e.g. '2 mins')
        
        % Keep track of reqFreq. First dimension same size as idArr_unique, second
        % dimension depends on how many different frequency there are for
        % the id
        reqFreqArrArr;
        reqFreqMultipleArrArr;
        counterArr; % When the id's data arrives, the corresponding entry +1
        
        histBarArrArr; 
    end
    events
        publishHistDataEvt;
    end
end