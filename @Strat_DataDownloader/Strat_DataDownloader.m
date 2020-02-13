%% Dummy strategy used for historical data downloading

classdef Strat_DataDownloader < StrategyBase
    methods
        % Constructor
        function obj = Strat_DataDownloader(signalArr,LengSignalStorage,contractArr,comboDefArrArr,strategyName)
            obj = obj@StrategyBase(signalArr,LengSignalStorage,contractArr,comboDefArrArr,strategyName);

            % TBD: these details have to be filled automatically, not
            % hardcoded
			reqDetail.ibContract = obj.contractArr{1,1};
			reqDetail.barDuration = DateTimeUtils.intoProperStr(signalArr{1}.barDuration);
			reqDetail.bidask = 'MIDPOINT';
			reqDetail.bartick = 'bar';
			reqDetail.histDataLeng = DateTimeUtils.getMaxHistAllowed(reqDetail.barDuration);
			reqDetail.reqFreq = '1 h'; % Doesn't matter because we are only going to make one non-repeated request
            obj.myCalibrator = Calib_DataDownloader(obj,{reqDetail});
        end
        function signalDecision(obj)
            % Empty
        end
        function orderDecision(obj)
            % Empty
        end
        function output = allReqDone(obj)
            output = 1.0 - max(obj.reqArr - obj.reqArr .* obj.doneArr);
        end
        function histDataReceived(obj, openVec, highVec, lowVec, closeVec)
            % TBD: What to do? Call DataBaseManager function?
        end
    end
    properties
		% For reqArr and doneArr, the entries are:
        % Hist mkt data, ReportSnapshot, ReportsFinSummary, ReportRatios, ReportsFinStatements, RESC, CalendarReport
        reqArr = [0 0 0 0 0 0 0];
        doneArr = [0 0 0 0 0 0 0];
    end
end