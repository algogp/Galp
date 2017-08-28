%% Main file for the Generic Algo Platform (Galp)

classdef Galp
    methods (Static)
        % optionalFileName should be something like 'xxx.mat'
        function start(optionalFileName)
            persistent runningFlag;
            if isempty(runningFlag)
                Galp_setup;
                runningFlag = 1;
            else
                disp('Galp is already running!');
            end
            if nargin > 0 % If we are given a saved file name...
                contextSingleton = EventContext.getInstance;
                contextSingleton.mySaveLoadManager.loadPositions(optionalFileName);
            end
            GeneralUtils.logWrapper('Platform started.');
        end
        function download()
            Galp_datacentre;
        end
        function pause()
            contextSingleton = EventContext.getInstance;
            contextSingleton.myStrategyManager.turnOnOffAllStrats(0);
            GeneralUtils.logWrapper('Trading paused.');
        end
        
        function resume()
            contextSingleton = EventContext.getInstance;
            contextSingleton.myStrategyManager.turnOnOffAllStrats(1);
            GeneralUtils.logWrapper('Trading resumed.');
        end
        
        function liquidateAll()
            contextSingleton = EventContext.getInstance;
            contextSingleton.myPortfolioManager.liqAll;
        end
        
        function verStr = version()
            verStr = 'Galp 3.1, September 2016';
            disp(verStr);
        end
        
        function stop()
            delete(timerfind);
            try
                % Check if Galp is running by getting the EventContext
                contextSingleton = EventContext.getInstance;
                
                % Save before stopping
                mySLMHandle = contextSingleton.mySaveLoadManager;
                mySLMHandle.saveWorkspace;
                
                GeneralUtils.logWrapper('Platform stopped.');
                clear;
                clear classes;
                clc;
            catch
                return;
            end
        end
        
        function report()
            contextSingleton = EventContext.getInstance;
            contextSingleton.myPortfolioManager.updateSecurityHoldings;
            contextSingleton.myPortfolioManager.MTM;
            disp(Courrier.MO2str);
        end
    end
end