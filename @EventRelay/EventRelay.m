%% Event Relay

% To implement this file, refer to EventGenerator
% This is called EventRelay because it receives COM event and triggers
% standard Matlab styled event, acting as a relay

classdef EventRelay < handle
    methods
        function obj = EventRelay()
            obj.ibError = '';
            
            % First element is id, second is data
            obj.bidSize = [0, 0];
            obj.askSize = [0, 0];
            obj.lastSize = [0, 0];
            obj.volume = [0, 0];
            obj.bidPrice = [0, 0.0];
            obj.askPrice = [0, 0.0];
            obj.lastPrice = [0, 0.0];
            
            obj.lastBar = Bar(0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0);
        end
        
        function publishIBError(obj)
            notify(obj,'publishIBErrorEvt',ToggleEventData(obj.ibError));
        end
        
        function publishBidSize(obj)
            notify(obj,'publishBidSizeEvt',ToggleEventData(obj.bidSize));
        end
        function publishAskSize(obj)
            notify(obj,'publishAskSizeEvt',ToggleEventData(obj.askSize));
        end   
        function publishLastSize(obj)
            notify(obj,'publishLastSizeEvt',ToggleEventData(obj.lastSize));
        end
        function publishVolume(obj)
            notify(obj,'publishVolumeEvt',ToggleEventData(obj.volume));
        end
        function publishBidPrice(obj)
            notify(obj,'publishBidPriceEvt',ToggleEventData(obj.bidPrice));
        end
        function publishAskPrice(obj)
            notify(obj,'publishAskPriceEvt',ToggleEventData(obj.askPrice));
        end
        function publishLastPrice(obj)
            notify(obj,'publishLastPriceEvt',ToggleEventData(obj.lastPrice));
        end
        
        function publishLastBar(obj)
            notify(obj,'publishLastBarEvt',ToggleEventData(obj.lastBar));
        end
    end
    
    properties
        ibError;
        
        bidSize;
        askSize;
        lastSize;
        volume;
        bidPrice;
        askPrice;
        lastPrice;
        
        lastBar;
    end
    
    events
        publishIBErrorEvt;
        
        publishBidSizeEvt;
        publishAskSizeEvt;
        publishLastSizeEvt;
        publishVolumeEvt;
        publishBidPriceEvt;
        publishAskPriceEvt;
        publishLastPriceEvt;
        
        publishLastBarEvt;
    end

end