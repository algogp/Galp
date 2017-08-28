classdef Bar
    methods
        function obj = Bar(Id, Time, Open, High, Low, Close, Volume, WAP, BarDuration)
            obj.id = Id;
            obj.time = Time;
            obj.open = Open;
            obj.high = High;
            obj.low = Low;
            obj.close = Close;
            obj.volume = Volume;
            obj.wap = WAP;
            obj.barDuration = BarDuration;
        end
        function newBar = FxBarInvert(origBar)
            % TBD: Implement function that convert Ccy1.Ccy2 bar to
            % Ccy2.Ccy1 bar.
        end
%         function obj = set.barDuration(obj,barDuration_)
%             obj.barDuration = barDuration_; % in number of seconds
%         end
    end
    properties
        id;
        time;
        open;
        high;
        low;
        close;
        volume;
        wap;
        barDuration; % in number of seconds
    end
end