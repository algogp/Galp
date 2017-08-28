classdef (Sealed) EventContext < handle
    methods (Access = private)
        % Constructor
        function obj = EventContext(varargin)
            if nargin > 0
                ibHandle = varargin{1}{1};
                baseCcy = varargin{1}{2};
                saveloadInputs  = varargin{1}{3};
                emailInputs = varargin{1}{4};
                logInputs = varargin{1}{5};
                obj.myIbHandle = ibHandle;
                obj.myFXManager = FXManager.getInstance(ibHandle,baseCcy);
                obj.myPortfolioManager = PortfolioManager.getInstance(ibHandle);
                obj.myOrderManager = OrderManager.getInstance(ibHandle,baseCcy);
                obj.mySaveLoadManager = SaveLoadManager.getInstance(saveloadInputs);
                obj.myEmailManager = EmailManager(emailInputs);
                obj.myHistDataManager = HistDataManager.getInstance(ibHandle);
                obj.myStrategyManager = StrategyManager.getInstance;
                obj.myLogManager = LogManager.getInstance(logInputs);
            end
        end
    end
    methods (Static)
        function singleObj = getInstance(varargin)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = EventContext(varargin);
            end
            singleObj = localObj;
        end
    end
    methods
        function addEventRelay(obj, id)
            numExistingEventRelay = length(obj.myEventRelaysArr);
            obj.myEventRelaysArr{1,numExistingEventRelay+1} = EventRelay();
            obj.idArr{1,numExistingEventRelay+1} = id;
        end
        function myBA = regNewBarAggregator(obj, id)
            obj.addEventRelay(id);
            numExistingEventRelay = length(obj.myEventRelaysArr);
            
            % Also add it to FXManager if contract is fx pair
            myDataIdMap = DataIdMap.getInstance;
            [contract,barDuration,bidask,bartick] = myDataIdMap.id2details(id);
            
            if strcmp(contract.currency,obj.myFXManager.baseCcy)==1
                % Regular BA
                myBA = BarAggregator(obj.myEventRelaysArr{1,numExistingEventRelay}, id, barDuration);
            elseif strcmp(contract.symbol,obj.myFXManager.baseCcy)==1
                myBA = BarAggregatorFXInv(obj.myEventRelaysArr{1,numExistingEventRelay}, id, barDuration);
            end
            if strcmp(contract.secType,'CASH')==1
                obj.myFXManager.listenToNew(id);
            end
        end
    end
    properties
        myIbHandle
        myEventRelaysArr = {};
        idArr;
        myPortfolioManager;
        myOrderManager;
        myFXManager;
        mySaveLoadManager;
        myEmailManager;
        myHistDataManager;
        myStrategyManager;
        myLogManager;
    end
end