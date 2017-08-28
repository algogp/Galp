%% FX Manager

% This class is responsible for providing FX conversion rate upon request

classdef (Sealed) FXManager < handle
    methods (Access = private)
        % Constructor
        function obj = FXManager(ibHandle,baseCcy)
            obj.myIbHandle = ibHandle;
            obj.baseCcy = baseCcy;
        end
    end
    methods (Static)
        function singleObj = getInstance(ibHandle,baseCcy)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = FXManager(ibHandle,baseCcy);
            end
            singleObj = localObj;
        end
    end
    methods
        function latestPrice = getLatestPrice(obj,ccyName)
            arrIndex = strmatch(ccyName, obj.ccyNameArr, 'exact');
            if ~isempty(arrIndex)
                latestPrice = obj.latestPriceArr{1,arrIndex};
            else
                GeneralUtils.logWrapper('FXManager::latestPrice: Cannot find currency');
            end
        end
        function listenToNew(obj,id)
            myDataIdMap = DataIdMap.getInstance;
            [fxContract,barDuration,bidask,bartick] = myDataIdMap.id2details(id);
            if strcmp(fxContract.symbol,obj.baseCcy) == 0
                ccyName = fxContract.symbol;
            elseif strcmp(fxContract.currency,obj.baseCcy) == 0
                ccyName = fxContract.currency;
            else
                GeneralUtils.logWrapper('FXManager::listenToNew: Contract does not involve base currency');
            end
            
            arrLeng = length(obj.idArr);
            
            contextSingleton = EventContext.getInstance;
            sourceIndex = find([contextSingleton.idArr{:}] == id);
            source = contextSingleton.myEventRelaysArr{1,sourceIndex};
            
            handle = event.listener(source,'publishLastBarEvt',@obj.newDataArrives);
            obj.subscriptionHandleArr{1,arrLeng+1} = handle;
            obj.idArr{1,arrLeng+1} = id;
            obj.ccyNameArr{1,arrLeng+1} = ccyName;
            obj.latestPriceArr{1,arrLeng+1} = [];
        end
        function newDataArrives(obj,src,dataPackage)
            newBar = dataPackage.message;
            arrIndex = find([obj.idArr{:}] == newBar.id);
            if length(arrIndex) > 1
                GeneralUtils.logWrapper('FXManager::newDataArrives: Duplicated currency entries');
            end
            obj.latestPriceArr{1,arrIndex(1)} = newBar.close;
        end
    end
    properties
        myIbHandle;
        baseCcy = 'USD';
        
        subscriptionHandleArr;
        idArr;
        ccyNameArr;
        latestPriceArr;
    end
end