%% BarAggregator that flips the FX pair
% For example, the BarAggregatorFXInv object that listens to the USD.JPY
% incoming data stream would provide aggregated bars of JPY.USD prices

classdef BarAggregatorFXInv < BarAggregator
    methods
        % Constructor
        function obj = BarAggregatorFXInv(source, id, barDuration)
            obj = obj@BarAggregator(source, id, barDuration);
        end
        
        % When updating fx-inverted aggregated bar, high of USD.XXX would
        % become low of XXX.USD, etc.
        function updateAggBar(obj,newBar)
            % Use mid price ((high + low)/2) as effective fx conversion
            % rate
            effFxRate = (newBar.high + newBar.low)/2;
            % Done only when first incoming bar is received
            if sum(sum(obj.barFilledCheck) == 1)
                obj.aggregatedBar.time = newBar.time;
                obj.aggregatedBar.open = 1/newBar.open;
                obj.aggregatedBar.low = 1/newBar.high;
                obj.aggregatedBar.high = 1/newBar.low;
                obj.aggregatedBar.close = 1/newBar.close;
                obj.aggregatedBar.volume = newBar.volume*effFxRate;
            else
                obj.aggregatedBar.high = max(obj.aggregatedBar.high, 1/newBar.low);
                obj.aggregatedBar.low = min(obj.aggregatedBar.low, 1/newBar.high);
                obj.aggregatedBar.close = 1/newBar.close;
                obj.aggregatedBar.volume = obj.aggregatedBar.volume + newBar.volume*effFxRate;
                % obj.aggregatedBar.wap = ; % Not implemented yet. Do
                % we have to?
            end
        end
    end
end