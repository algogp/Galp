%% IB ActiveX COM event handler

% When a new event case is added here, don't forget to also add it
% to GeneralUtils.ibEventList()

% To implement this file, refer to IBEXAMPLEREALTIMEEVENTHANDLER
% (but instead of doing set(t,'Data',data), trigger Matlab event)

function ibEventHandler(varargin)

contextSingleton = EventContext.getInstance;

switch varargin{end}
    
    case 'errMsg'
%         contextSingleton.myEventRelay.ibError = varargin{5};
%         contextSingleton.myEventRelay.publishIBError;
        disp(varargin{5});
%     case 'tickSize'
%         switch varargin{6}.tickType
%             case 0
%                 % BID SIZE
%                 contextSingleton.myEventRelay.bidSize = [varargin{6}.id,...
%                                                         varargin{6}.size];
%                 contextSingleton.myEventRelay.publishBidSize;            
%             case 3
%                 % ASK SIZE
%                 contextSingleton.myEventRelay.askSize = [varargin{6}.id,...
%                                                         varargin{6}.size];
%                 contextSingleton.myEventRelay.publishAskSize;              
%             case 5
%                 % LAST SIZE
%                 contextSingleton.myEventRelay.lastSize = [varargin{6}.id,...
%                                                          varargin{6}.size];
%                 contextSingleton.myEventRelay.publishLastSize;              
%             case 8
%                 % VOLUME
%                 contextSingleton.myEventRelay.volume = [varargin{6}.id,...
%                                                         varargin{6}.size];
%                 contextSingleton.myEventRelay.publishVolume;              
%         end
%     case 'tickString'
%         switch varargin{6}.tickType
%             case 45
%                 
%         end
%     case 'tickPrice'
%         switch varargin{7}.tickType
%             case 1
%                 % BID PRICE
%                 contextSingleton.myEventRelay.bidPrice = [varargin{7}.id,...
%                                                           varargin{7}.price];
%                 contextSingleton.myEventRelay.publishBidPrice;
%             case 2
%                 % ASK PRICE
%                 contextSingleton.myEventRelay.askPrice = [varargin{7}.id,...
%                                                           varargin{7}.price];
%                 contextSingleton.myEventRelay.publishAskPrice;                
%             case 4
%                 % LAST PRICE
%                 contextSingleton.myEventRelay.lastPrice = [varargin{7}.id,...
%                                                            varargin{7}.price];
%                 contextSingleton.myEventRelay.publishLastPrice;                
%         end
    case 'realtimeBar'
        idTemp = varargin{12}.tickerId;
        if idTemp <= length(contextSingleton.myEventRelaysArr)
            contextSingleton.myEventRelaysArr{idTemp}.lastBar = Bar(varargin{12}.tickerId,...
                                                        varargin{12}.time,...
                                                        varargin{12}.open,...
                                                        varargin{12}.high,...
                                                        varargin{12}.low,...
                                                        varargin{12}.close,...
                                                        varargin{12}.volume,...
                                                        varargin{12}.WAP,...
                                                        5); % 5 s bar
            contextSingleton.myEventRelaysArr{idTemp}.publishLastBar;
        else
            % idTemp > number of element in array
            GeneralUtils.logWrapper('ibEventHandler::ibEventHandler: Id not registered.');
        end
    case 'accountSummary'
        switch varargin{8}.tag
            case 'NetLiquidation'
                contextSingleton.myPortfolioManager.ibNetLiquidation = varargin{8}.value;
            case 'TotalCashValue'
                contextSingleton.myPortfolioManager.ibTotalCashValue = varargin{8}.value;
            case 'SettledCash'
                contextSingleton.myPortfolioManager.ibSettledCash = varargin{8}.value;
            case 'AccruedCash'
                contextSingleton.myPortfolioManager.ibAccruedCash = varargin{8}.value;
            case 'BuyingPower'
                contextSingleton.myPortfolioManager.ibBuyingPower = varargin{8}.value;
            case 'EquityWithLoanValue'
                contextSingleton.myPortfolioManager.ibEquityWithLoanValue = varargin{8}.value;
            case 'PreviousDayEquityWithLoanValue'
                contextSingleton.myPortfolioManager.ibPreviousDayEquityWithLoanValue = varargin{8}.value;
            case 'RegTMargin'
                contextSingleton.myPortfolioManager.ibRegTMargin = varargin{8}.value;
            case 'SMA'
                contextSingleton.myPortfolioManager.ibSMA = varargin{8}.value;
            case 'InitMarginReq'
                contextSingleton.myPortfolioManager.ibInitMarginReq = varargin{8}.value;
            case 'MaintMarginReq'
                contextSingleton.myPortfolioManager.ibMaintMarginReq = varargin{8}.value;
            case 'AvailableFunds'
                contextSingleton.myPortfolioManager.ibAvailableFunds = varargin{8}.value;
            case 'ExcessLiquidity'
                contextSingleton.myPortfolioManager.ibExcessLiquidity = varargin{8}.value;
            case 'Cushion'
                contextSingleton.myPortfolioManager.ibCushion = varargin{8}.value;
            case 'DayTradesRemaining'
                contextSingleton.myPortfolioManager.ibDayTradesRemaining = varargin{8}.value;
            case 'Leverage'
                contextSingleton.myPortfolioManager.ibDayibLeverageTradesRemaining = varargin{8}.value;
        end
    case 'updatePortfolioEx'
        % varargin{3} has fields:
        % conId, currency, exchange, expiry, localSymbol, primaryExchange,
        % secId, secType, strike, symbol, tradingClass
        % varargin{11} has fields:
        % contract,position,marketPrice,marketValue,unrealizedPNL,realizedPNL
        contextSingleton.myPortfolioManager.newPortfolioUpdate({varargin{3},varargin{11}});
    case 'nextValidId'
        contextSingleton.myOrderManager.nextOrderIdStore = varargin{3};

    case 'updateMktDepth'
        % varargin{9} has fields:
        % Type, Source, EventID, id, position, operation,
        % side, prize, size
        disp('here');
    case 'updateMktDepthL2'
        disp('here');
    case 'historicalData'
        % varargin{13} has fields:
        % Type, Source, EventID, reqId, date, open, high, low, close,
        % volume, barCount, WAP, hasGaps
        
        % Note: After all the data is delivered there will be an extra
        % notification sent, with the date string being "finished-<start
        % time>-<end time>" and all other fields = -1
        
        % Retrieve barDuration using reqId
        myIdMap = DataIdMap.getInstance;
        [ibContract,barDuration,bidask,bartick] = myIdMap.id2details(varargin{13}.reqId);
        barDurationInSecond = DateTimeUtils.intoNumOfSecondWrapper(barDuration);
        barTemp = Bar(varargin{13}.reqId,...
                        varargin{13}.date,...
                        varargin{13}.open,...
                        varargin{13}.high,...
                        varargin{13}.low,...
                        varargin{13}.close,...
                        varargin{13}.volume,...
                        varargin{13}.WAP,...
                        barDurationInSecond);

        % Push to HistDataManager
        contextSingleton.myHistDataManager.receiveNewBar(barTemp);
    case 'execDetailsEx'
        % varargin{1,4} is the IContract object
        % varargin{1,5} is the IExecution object
        % varargin{1,6} has fields:
        % EventID, reqId, contract, execution
        orderId = varargin{1,5}.orderId;
        avgFillPrice = varargin{1,5}.avgPrice;
        GeneralUtils.logWrapper(['Temp Debug: Id and price are  ' num2str(orderId) '   ' num2str(avgFillPrice)]);
        % 'status' is required for legacy reason:
        % OrderManager.newOrderStatusUpdate was originally written to
        % listen to orderStatus events
        status = 'Filled';

        % Galp 2.1: Do not rely on execDetailsEx messages
%         contextSingleton.myOrderManager.newOrderStatusUpdate(orderId, avgFillPrice, status);
    case 'execDetailsEnd'
%         varargin;        
    case 'orderStatus'
        % varargin{13} has fields:
        % EventID, id, status, filled, remaining, avgFillPrice, permId,
        % parentId, lastFillPrice, clientId, whyHeld
        orderId = varargin{13}.id;
        avgFillPrice = varargin{13}.avgFillPrice;
        status = varargin{13}.status;
        
        % Galp 2.0: Do not rely on orderStatus messages
        contextSingleton.myOrderManager.newOrderStatusUpdate(orderId, avgFillPrice, status);
    case 'position'
        % varargin{1,7} has fields:
        % Type='position', EventID=106, account, contract, position, avgCost
        contractDetailsObj = GeneralUtils.contract2details(varargin{1,7}.contract);
        secStr = [contractDetailsObj.symbol '.' contractDetailsObj.currency];
        holding = varargin{1,7}.position;
        secType = contractDetailsObj.secType;
        exchange = contractDetailsObj.exchange;
        contextSingleton.myPortfolioManager.updatePositions(secStr,holding,secType,exchange);
    case 'positionEnd'
        % varargin{1,3} has fields:
        % Type='positionEnd', EventID=107
        if contextSingleton.myPortfolioManager.flagLiqAllOrdered == 1
            contextSingleton.myPortfolioManager.executeLiqAll;
        end
    case 'fundamentalData'
        varargin{1,5}.data;
end

end