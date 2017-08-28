%% Date Time Utilities
% All the time related util functions go here
% This class only contains static functions

classdef DateTimeUtils
    methods (Static)
        function numSecond = intoNumOfSecondWrapper(timeStr)
            [howMany, timeUnit] = strtok(timeStr, ' ');
            numSecond = DateTimeUtils.intoNumOfSecond( ...
                str2double(strtrim(howMany)), strtrim(timeUnit));
        end
        function numSecond = intoNumOfSecond(howMany, timeUnit)
            % timeUnit = 's', 'm', 'h' etc.
            switch timeUnit
                case {'s','S','second','Second','sec','Sec', ...
                        'seconds','Seconds','secs','Secs'}
                    numSecond = howMany;
                %Note: 'M' is reserved for month
                case {'m','minute','Minute','min','Min', ...
                        'minutes','Minutes','mins','Mins'}
                    numSecond = howMany * 60;
                case {'h','H','hour','Hour','hr','Hr', ...
                        'hours','Hours','hrs','Hrs'}
                    numSecond = howMany * 60 * 60;
                case {'d','D','day','Day', ...
                        'days','Days'}
                    numSecond = howMany * 60 * 60 * 24;
                case {'w','W','week','Week','wk','Wk', ...
                        'weeks','Weeks','wks','Wks'} % 5-day week assumed
                    numSecond = howMany * 60 * 60 * 24 * 5;
                case {'M'}
                    numSecond = howMany * 60 * 60 * 24 * 21; % 21-day month assumed
                case {'y','Y','year','Year','yr','Yr', ...
                        'years','Years','yrs','Yrs'}
                    numSecond = howMany * 60 * 60 * 24 * 252; % 250 trading days assumed
            end
        end
        function properStr = intoProperStr(improperStr)
            % Translated '1 s', '2 s', '1 m', '2 m' etc. into '1 sec', '2
            % secs', '1 min', '2 mins' etc.
            % Note: This function DOES NOT transform '60 s' into '1 min',
            % etc.
            [howMany, timeUnit] = strtok(improperStr);
            timeUnitTrimmed = strtrim(timeUnit);
            switch timeUnitTrimmed
                case {'s','S','second','Second','sec','Sec', ...
                        'seconds','Seconds','secs','Secs'}
                    properTimeUnit = 'sec';
                case {'m','M','minute','Minute','min','Min', ...
                        'minutes','Minutes','mins','Mins'}
                    properTimeUnit = 'min';
                case {'h','H','hour','Hour','hr','Hr', ...
                        'hours','Hours','hrs','Hrs'}
                    properTimeUnit = 'hour';
                case {'d','D','day','Day', ...
                        'days','Days'}
                    properTimeUnit = 'day';
            end
            properStr = [howMany,' ',properTimeUnit];
            % Single or plural
            if str2double(howMany) > 1.0
                properStr = [properStr,'s'];
            end
        end
        function anchorPointStr = findAnchorPoint(refTimeStr, numSec, lastOrNext)
            %- Do not work well with weird intervals (such as 90m, 45m). In
            %  such cases, this function does not know that, e.g. 12:00 is a
            %  solution but 13:00 is not.
            %- If we want to account for the above, we have to write a more
            %  advanced version that considers time unit that is one order
            %  above numSec (e.g. numSec is of the order of min, the
            %  advanced version has to consider also hour, etc.)
            %- Another possibility is to do waitTimeInSecond = min(60 - whichSecond,numSec -
            %  mod(whichSecond, numSec)) etc. to reduce wait time
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % lastOrNext = {'L','l','last','Last','LAST'} or {'N','n','next','Next','NEXT'}
            % Examples: (assuming now = 14:23:13)
            % findAnchorPoint(now, 5, 'n')      = 14:23:15
            % findAnchorPoint(now, 10, 'n')     = 14:23:20
            % findAnchorPoint(now, 15, 'n')     = 14:23:15
            % findAnchorPoint(now, 20, 'n')     = 14:23:20
            % findAnchorPoint(now, 60, 'n')     = 14:24:00
            % findAnchorPoint(now, 120, 'n')    = 14:24:00
            % findAnchorPoint(now, 300, 'n')    = 14:25:00
            % findAnchorPoint(now, 600, 'n')    = 14:30:00
            % findAnchorPoint(now, 1800, 'n')   = 14:30:00
            % findAnchorPoint(now, 3600, 'n')   = 15:00:00
            % findAnchorPoint(now, 14400, 'n')  = 16:00:00
            % ...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            whichYear = year(refTimeStr);
            whichMonth = month(refTimeStr);
            whichDay = day(refTimeStr);
            whichHour = hour(refTimeStr);
            whichMinute = minute(refTimeStr);
            whichSecond = second(refTimeStr);
            switch lastOrNext
%                 case {'L','l','last','Last','LAST'}
%                     if (numSec < 60)
%                         
%                     elseif ()
% 
%                     elseif ()
% 
%                     end
                case {'N','n','next','Next','NEXT'}
                    % Use mod to find nearest time
                    if (numSec < 60)
                        % waitTimeInSecond = ceil(whichSecond/numSec)*numSec - whichSecond;
                        waitTimeInSecond = numSec - mod(whichSecond, numSec);
                    elseif (numSec >= 60) & (numSec < 60*60)
                        % waitTimeInSecond = ceil((whichMinute*60+whichSecond)/numSec)*numSec - (whichMinute*60+whichSecond);
                        waitTimeInSecond = numSec - mod(DateTimeUtils.intoNumOfSecond(whichMinute,'m')+whichSecond, numSec);
                    elseif (numSec >= 60*60) & (numSec < 24*60*60)
                        % waitTimeInSecond = ceil((whichHour*60*60+whichMinute*60+whichSecond)/numSec)*numSec - (whichHour*60*60+whichMinute*60+whichSecond);
                        waitTimeInSecond = numSec - mod(DateTimeUtils.intoNumOfSecond(whichHour,'h')+DateTimeUtils.intoNumOfSecond(whichMinute,'m')+whichSecond, numSec);
                    else
                        % GeneralUtils.logWrapper('DateTimeUtils::anchorPointStr: Interval not supported.');
                        waitTimeInSecond = 0.0;
                    end
            end
            anchorPointStr = DateTimeUtils.DateTimeShift(refTimeStr, [0,0,0,0,0,waitTimeInSecond]);
        end
        function dateTimeStr = posix2DateTimeStr(posixTime)
            % Native IB time stamp is in POSIX format, i.e. number of
            % seconds since 1 Jan 1970
            dateTimeStr = datestr(datenum([1970 1 1 0 0 posixTime]),'yyyy-mm-dd HH:MM:SS.FFF');
        end
        
        function newDateTimeStr = DateTimeShift(origDateTimeStr, timeToAdd)
            % timeToAdd = [#Yr,#Mon,#Day,#Hr,#Min,#Sec]
            whichYear = year(origDateTimeStr);
            whichMonth = month(origDateTimeStr);
            whichDay = day(origDateTimeStr);
            whichHour = hour(origDateTimeStr);
            whichMinute = minute(origDateTimeStr);
            whichSecond = second(origDateTimeStr);
            
            newDateTimeStr = datestr(datenum([whichYear+timeToAdd(1),...
                                              whichMonth+timeToAdd(2),...
                                              whichDay+timeToAdd(3),...
                                              whichHour+timeToAdd(4),...
                                              whichMinute+timeToAdd(5),...
                                              whichSecond+timeToAdd(6)]),'yyyy-mm-dd HH:MM:SS.FFF');
        end
        function ratio = DateTimeRatio(startTimeStr, endTimeStr, refTimeStr)
            % DateTimeRatio(04:00, 05:30, 04:45) = 0.5, etc.
            % Catch errors
            if (datenum(startTimeStr) > datenum(endTimeStr))
                GeneralUtils.logWrapper('DateTimeUtils::DateTimeRatio: startTimeStr later than endTimeStr');
%             elseif (datenum(refTimeStr) < datenum(startTimeStr)) |...
%                     (datenum(endTimeStr) < datenum(refTimeStr))
%                 disp('DateTimeUtils::DateTimeRatio: refTimeStr outside range');
            end
            ratio = (datenum(refTimeStr)-datenum(startTimeStr))/(datenum(endTimeStr)-datenum(startTimeStr));
        end
        function intOutput = intoNumPeriod(timeframeStrLong,timeframeStrShort)
            numSecLong = DateTimeUtils.intoNumOfSecondWrapper(timeframeStrLong);
            numSecShort = DateTimeUtils.intoNumOfSecondWrapper(timeframeStrShort);
            intOutput = round(numSecLong/numSecShort);
        end
        function maxHistAllowed = getMaxHistAllowed(barDurationStr)
            % See table at the bottom of https://www.interactivebrokers.com/en/software/api/apiguide/tables/historical_data_limitations.htm
            % barDurationStr must be in proper string formaat (i.e. secs,
            % mins etc.)
            numSecond = DateTimeUtils.intoNumOfSecondWrapper(barDurationStr);
            if numSecond <= 1.0
                maxHistAllowed = '1800 S';
            elseif numSecond <= 5.0
                maxHistAllowed = '7200 S';
            elseif numSecond <= 15.0
                maxHistAllowed = '14400 S';
            elseif numSecond <= 30.0
                maxHistAllowed = '28800 S';
            elseif numSecond <= 60.0
                maxHistAllowed = '1 D';
            elseif numSecond <= 120.0
                maxHistAllowed = '2 D';
            elseif numSecond <= 600.0
                maxHistAllowed = '1 W';
            elseif numSecond <= 1200.0
                maxHistAllowed = '2 W';
            elseif numSecond <= 28800.0
                maxHistAllowed = '1 M';
            else
                maxHistAllowed = '1 Y';
            end
        end
    end
end