%% Strategy example: buy when close(t_0) > close(t_-1), sell otherwise

classdef Strat_BuyUpSellDown < StrategyBase
    methods
        % Constructor
        function obj = Strat_BuyUpSellDown(signalArr,LengSignalStorage,contractArr,comboDefArrArr,strategyName)
            obj = obj@StrategyBase(signalArr,LengSignalStorage,contractArr,comboDefArrArr,strategyName);
        end
        function decision = signalDecision(obj)
            signalArr = obj.signalArrArr{1,1};
            currentLeng = length(signalArr);
            if (currentLeng > 1)
                if (signalArr{1,1} > signalArr{1,2})
                    disp('BUY');
                    decision = 1;
                elseif (signalArr{1,1} < signalArr{1,2})
                    disp('SELL');
                    decision = -1;
                else
                    disp('FLAT');
                    decision = 0;
                end
            end
        end
        function orderDecision(obj)
            % Is signal telling us to trade?
            decision = obj.signalDecision;
            % Is there any dangling orders?
            
            % Do we have enough margin left?
            
            % Have we reached the max holding limit for this strategy?
            
        end
    end
end