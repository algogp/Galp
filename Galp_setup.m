%% Read info from the setup file in order to set the platform up

function Galp_setup()
%% Basic setup
% Only FX spot trading is supported
secType = 'CASH';
% Read Excel file
[num_core, txt_core, raw_core] = xlsread('GalpSetup.xlsx','Core');
[num_sig, txt_sig, raw_sig] = xlsread('GalpSetup.xlsx','Signals');
header_sig = raw_sig(1,:);
body_sig = raw_sig(2:end,:);
[num_strat, txt_strat, raw_strat] = xlsread('GalpSetup.xlsx','Strategies');
header_strat = raw_strat(1,:);
body_strat = raw_strat(2:end,:);

% Setup the core Galp singleton
headerColIndex = 2;
dataColIndex = 3;
% Connect to IB
portNumber = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Port Number'),dataColIndex};
ib = ibtws('',portNumber); % Pay attention to port number

% Account base currency
baseCcy = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Account Base Ccy'),dataColIndex};
% Email inputs
emailInputs.sender = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Sender Address'),dataColIndex};
emailInputs.password = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Sender Password'),dataColIndex};
% Saving and Loading inputs
saveloadInputs.pathName = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Saved File Path'),dataColIndex};
saveloadInputs.fileName = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Saved File Name'),dataColIndex};
% Log inputs
logInputs.logPath = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Log File Path'),dataColIndex};
logInputs.logFile = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Log File Name'),dataColIndex};

% Construct singleton
contextSingleton = EventContext.getInstance(ib.Handle,baseCcy,saveloadInputs,emailInputs,logInputs);
myIdMap = DataIdMap.getInstance;

% Create timer
startDelaySecond = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Start Delay (second)'),dataColIndex};
intervalSecond = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Interval (second)'),dataColIndex};
emailRecipient = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Recipient Address'),dataColIndex};
emailTitle = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Email Title'),dataColIndex};
myTimer = timer('BusyMode','drop', ...
                'StartDelay',startDelaySecond, ...
                'Period',intervalSecond, ...
                'TimerFcn',{@timerCallback.TCB,emailRecipient,emailTitle}, ...
                'ErrorFcn',@(~,~) GeneralUtils.logWrapper('Main loop timer error.'), ...
                'ExecutionMode','fixedDelay');
start(myTimer);

% Register events
GeneralUtils.regEvents(ib.Handle);

%% Contract bar aggregators
% Each unique combination of contract & bar interval & bid/ask would
% require separate bar aggregator, e.g. USD.JPY 30 s bid, USD.JPY 10 m ask,
% USD.JPY 10 m midpoint...

% Construct unique data subscription array
barTickersStringArr = body_sig(:,findIndexFromRawCol(header_sig,'[Bar Tickers]'));
barDurationsStringArr = body_sig(:,findIndexFromRawCol(header_sig,'[Bar Durations]'));
barBidAsksStringArr = body_sig(:,findIndexFromRawCol(header_sig,'[Bar Bid/Ask]'));
[uniqueTickersArr, uniqueDurationsArr, uniqueBidAsksArr] = getUniqueTickersDurations(barTickersStringArr,barDurationsStringArr,barBidAsksStringArr);
numUniqueContract = length(uniqueTickersArr);

% Construct bar aggregators
uniqueBarAggregatorArr = cell(1,numUniqueContract);
exchangeName = raw_core{findIndexFromRawCol(raw_core(:,headerColIndex),'Exchange Name'),dataColIndex};
for i = 1:numUniqueContract
    ccyArr = parseIntoArray(uniqueTickersArr{i}, '.', 0);
    ibContract = GeneralUtils.makeIbDelta1Contract(ib.Handle,ccyArr{1},secType,exchangeName,ccyArr{2});
    id = myIdMap.details2id(ibContract,uniqueDurationsArr{1,i},uniqueBidAsksArr{1,i},'bar');
    BA = contextSingleton.regNewBarAggregator(id);
    uniqueBarAggregatorArr{1,i} = BA;
end

%% Signal subscription setup
fhTemp = @(x) all(isnan(x(:))); % Find NaN in an array

% Construct signals array
numSignals = size(body_sig,1);
signalsArr = cell(1,numSignals);
signalStringArr = body_sig(:,findIndexFromRawCol(header_sig,'Signal'));
signalNamesArr = body_sig(:,findIndexFromRawCol(header_sig,'Name'));
signalStorageLengArr = body_sig(:,findIndexFromRawCol(header_sig,'Storage Length'));
sigBarDurArr = body_sig(:,findIndexFromRawCol(header_sig,'Signal Bar Duration'));

sigSpecificParamsStartFrom = findIndexFromRawCol(header_sig,'Specific Inputs');
for i = 1:numSignals
    % Pick out the bar aggregators for this signal factory(in the right order)
    baArr = getBAArr(uniqueTickersArr, uniqueDurationsArr, uniqueBidAsksArr, ...
        uniqueBarAggregatorArr,barTickersStringArr{i},barDurationsStringArr{i},barBidAsksStringArr{i});
    % Take care of signal specific parameters (i.e. those that are not
    % included in the SignalFactoryBase class)
    sigRowTemp = body_sig(i,:);
    sigSpecificParamsStartTo = max(find(~cellfun(fhTemp,sigRowTemp)));
    % Create SF function handle
    SFStr = signalStringArr{i};
    SFFuncHandle = str2func(SFStr);
    if sigSpecificParamsStartTo < sigSpecificParamsStartFrom % No specific params
        SF = SFFuncHandle(baArr,sigBarDurArr{i},signalStorageLengArr{i},signalNamesArr{i});
    else
        sigSpecificParamsArr = constructSpecParamsArr(body_sig(i,sigSpecificParamsStartFrom:sigSpecificParamsStartTo));
        SF = SFFuncHandle(baArr,sigBarDurArr{i},signalStorageLengArr{i},signalNamesArr{i},sigSpecificParamsArr);
    end
    signalsArr{i} = SF;
end

%% Strategies setup
% TBD: Integrity check - is any strategy asking for non-existent signal?

numStrats = size(body_strat,1);
stratsArr = cell(1,numStrats);
stratStringArr = body_strat(:,findIndexFromRawCol(header_strat,'Strategy'));
stratNameArr = body_strat(:,findIndexFromRawCol(header_strat,'Name'));
stratStorageLengArr = body_strat(:,findIndexFromRawCol(header_strat,'Storage Length'));

stratSignalsStringArr = body_strat(:,findIndexFromRawCol(header_strat,'[Signals]'));
stratContractsStringArr = body_strat(:,findIndexFromRawCol(header_strat,'[Traded Contracts]'));
stratWeightsStringArr = body_strat(:,findIndexFromRawCol(header_strat,'[Combo Weights]'));

stratSpecificParamsStartFrom = findIndexFromRawCol(header_strat,'Specific Inputs');
for i = 1:numStrats
    % Pick out the signals for this strategy(in the right order)
    sfArr = getSFArr(signalNamesArr,signalsArr,stratSignalsStringArr{i});
    % Construct contract array
    contractArr = constructContractArr(ib.Handle,secType,exchangeName,stratContractsStringArr{i});
    % Construct combo array array
    comboArrArr = constructComboArrArr(stratWeightsStringArr{i});
    % Take care of strategy specific parameters (i.e. those that are not
    % included in the StrategyBase class)
    stratRowTemp = body_strat(i,:);
    stratSpecificParamsStartTo = max(find(~cellfun(fhTemp,stratRowTemp)));
    % Create strat function handle
    StratStr = stratStringArr{i};
    StratFuncHandle = str2func(StratStr);
    if stratSpecificParamsStartTo < stratSpecificParamsStartFrom % No specific params
        strat = StratFuncHandle(sfArr,stratStorageLengArr{i},contractArr,comboArrArr,stratNameArr{i});
    else
        stratSpecificParamsArr = constructSpecParamsArr(body_strat(i,stratSpecificParamsStartFrom:stratSpecificParamsStartTo));
        strat = StratFuncHandle(sfArr,stratStorageLengArr{i},contractArr,comboArrArr,stratNameArr{i},stratSpecificParamsArr);
    end
    stratsArr{i} = strat;
end

%% HistDataManager::startTiming
% Note: Make sure all Calibrators have been set up before this
% is executed
contextSingleton.myHistDataManager.startTiming;

%% Make data requests
numId = length(myIdMap.idArr);
for i = 1:numId
    GeneralUtils.reqRealTimeBarsExWrapper(ib.Handle,i);
    pause(1); % Pause to avoid historical data pacing violation
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function outputInt = lengthToCheck()
% Check only the first 100 character when comparing strings
outputInt = 100;
end

function index = findIndexFromRawCol(rawCol, myStr)
% Remove NaN
fhTemp = @(x) all(isnan(x(:)));
rawCol(cellfun(fhTemp, rawCol)) = [];
strFindArr = strfind(rawCol,myStr);
index = find(~cellfun(@isempty,strFindArr));
end

function outputArr = parseIntoArray(inputString, delimitor, intoNum)
if isnumeric(inputString)
    outputArr = {inputString};
    return
end
% Split at delimitor
splitStr = strsplit(inputString,delimitor);
for i = 1:length(splitStr)
    % Collapse any space
    splitStr{1,i} = strtrim(splitStr{1,i});
    % Transform to num if necessary
    if intoNum == 1 && ~isnan(str2double(splitStr{1,i}))
        splitStr{1,i} = str2double(splitStr{1,i});
    end
end
outputArr = splitStr;
end

function [uniqueTickersArr,uniqueDurationsArr,uniqueBidAsksArr] = ...
    getUniqueTickersDurations(barTickersStringArr,barDurationsStringArr,barBidAsksStringArr)
uniqueTickersArr = {};
uniqueDurationsArr = {};
uniqueBidAsksArr = {};
for i = 1:length(barTickersStringArr)
    barTickerStringArr = parseIntoArray(barTickersStringArr{i},',',0);
    barDurationStringArr = parseIntoArray(barDurationsStringArr{i},',',0);
    barBidAskStringArr = parseIntoArray(barBidAsksStringArr{i},',',0);
    for j = 1:length(barTickerStringArr)
        barTicker = barTickerStringArr{j};
        barDuration = barDurationStringArr{j};
        barBidAsk = barBidAskStringArr{j};
        [uniqueTickersArr,uniqueDurationsArr,uniqueBidAsksArr] = ...
            insertIfNotIncluded(uniqueTickersArr,uniqueDurationsArr,uniqueBidAsksArr, ...
            barTicker,barDuration,barBidAsk);
    end
end
end

function [modifiedUniqueTickersArr,modifiedUniqueDurationsArr,modifiedUniqueBidAsksArr] ...
        = insertIfNotIncluded(uniqueTickersArr,uniqueDurationsArr,uniqueBidAsksArr, ...
        barTicker,barDuration,barBidAsk)
    newLength = length(uniqueTickersArr) + 1;
    modifiedUniqueTickersArr = uniqueTickersArr;
    modifiedUniqueDurationsArr = uniqueDurationsArr;
    modifiedUniqueBidAsksArr = uniqueBidAsksArr;
    if isempty(max(strncmp(barTicker,uniqueTickersArr,lengthToCheck) .* ...
        strncmp(barDuration,uniqueDurationsArr,lengthToCheck) .* ...
        strncmp(barBidAsk,uniqueBidAsksArr,lengthToCheck)))
    
        modifiedUniqueTickersArr{1,newLength} = barTicker;
        modifiedUniqueDurationsArr{1,newLength} = barDuration;
        modifiedUniqueBidAsksArr{1,newLength} = barBidAsk;
    elseif  max(strncmp(barTicker,uniqueTickersArr,lengthToCheck) .* ...
        strncmp(barDuration,uniqueDurationsArr,lengthToCheck) .* ...
        strncmp(barBidAsk,uniqueBidAsksArr,lengthToCheck)) < 1
        
        modifiedUniqueTickersArr{1,newLength} = barTicker;
        modifiedUniqueDurationsArr{1,newLength} = barDuration;
        modifiedUniqueBidAsksArr{1,newLength} = barBidAsk;
    end
end

function outputBAArr = getBAArr(uniqueTickersArr,uniqueDurationsArr,uniqueBidAsksArr, ...
    uniqueBarAggregatorArr,barTickersString,barDurationsString,barBidAsksString)
barTickersArr = parseIntoArray(barTickersString, ',', 0);
barDurationsArr = parseIntoArray(barDurationsString, ',', 0);
barBidAsksArr = parseIntoArray(barBidAsksString, ',', 0);
numBA = length(barTickersArr);
outputBAArr = cell(1,numBA);
for i = 1:numBA
    index = find(strncmp(barTickersArr{i},uniqueTickersArr,lengthToCheck) .* ...
        strncmp(barDurationsArr{i},uniqueDurationsArr,lengthToCheck) .* ...
        strncmp(barBidAsksArr{i},uniqueBidAsksArr,lengthToCheck));
    outputBAArr{i} = uniqueBarAggregatorArr{index};
end
end

function outputSFArr = getSFArr(signalNamesArr,signalsArr,stratSignalsString)
stratSignalsArr = parseIntoArray(stratSignalsString,',',0);
numSF = length(stratSignalsArr);
outputSFArr = cell(1,numSF);
for i = 1:numSF
    index = find(strncmp(stratSignalsArr{i},signalNamesArr,lengthToCheck));
    outputSFArr{i} = signalsArr{index};
end
end

function outputContractArr = constructContractArr(ibHandle,secType,exchangeName,stratContractsString)
stratContractsArr = parseIntoArray(stratContractsString,',',0);
numContract = length(stratContractsArr);
outputContractArr = cell(1,numContract);
for i = 1:numContract
    ccyArr = parseIntoArray(stratContractsArr{i},'.',0);
    ibContract = GeneralUtils.makeIbDelta1Contract(ibHandle,ccyArr{1},secType,exchangeName,ccyArr{2});
    outputContractArr{i} = ibContract;
end
end

function outputComboArrArr = constructComboArrArr(stratWeightsString)
% Input looks like '1,1,1;2,3,1;0.5,-1,-1'
% Output would be {{1,1,1},{2,3,1},{0.5,-1,-1}}
comboStringArr = parseIntoArray(stratWeightsString,';',0);
numOfArr = length(comboStringArr);
outputComboArrArr = cell(1,numOfArr);
for i = 1:numOfArr
    outputComboArrArr{i} = parseIntoArray(comboStringArr{i},',',1);
end
end

function outputSpecificParamsArr = constructSpecParamsArr(specificParamsCells)
numParams = size(specificParamsCells,2);
outputSpecificParamsArr = cell(1,numParams);
for i = 1:numParams
    tempStore = parseIntoArray(specificParamsCells{i},',',1);
    if length(tempStore) == 1
        outputSpecificParamsArr{i} = tempStore{1};
    else
        outputSpecificParamsArr{i} = tempStore;
    end
end
end