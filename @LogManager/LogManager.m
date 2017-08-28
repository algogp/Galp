%% Log Manager

classdef (Sealed) LogManager < handle
    methods (Access = private)
        % Constructor
        function obj = LogManager(logInputs)
            obj.logPath = logInputs.logPath;
            obj.logFile = logInputs.logFile;
        end
    end
    methods (Static)
        function singleObj = getInstance(logInputs)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = LogManager(logInputs);
            end
            singleObj = localObj;
        end
    end
    methods
        function writeToLog(obj,msgStr)
            fullPath = [obj.logPath obj.logFile];
            fileId = fopen(fullPath, 'a');
            fullStr = [datestr(clock,'yyyy-mm-dd HH:MM:SS.FFF') '    ' msgStr char(10)];
            fprintf(fileId, fullStr);
            fclose(fileId);
        end
    end
    properties
        logPath;
        logFile;
    end
end