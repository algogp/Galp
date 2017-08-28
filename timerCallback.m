%% Timer Callback Functions
% All the timer callback functions go here
% This class only contains static functions

classdef timerCallback
    methods (Static)
        function TCB(obj,event,emailRecipient,emailSubject)
            timerCallback.TCB_updatePortfolioInfo(obj,event);
            timerCallback.TCB_checkPosition(obj,event);
            timerCallback.TCB_sendEmail(obj,event,emailRecipient,emailSubject);
            timerCallback.TCB_saveWorkspace(obj,event);
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function TCB_checkPosition(obj,event)
             contextSingleton = EventContext.getInstance;
             myOMHandle = contextSingleton.myOrderManager;
             myOMHandle.checkOrderCompletion;
        end
        function TCB_updatePortfolioInfo(obj,event)
            contextSingleton = EventContext.getInstance;
            myPMHandle = contextSingleton.myPortfolioManager;
            myPMHandle.updateSecurityHoldings;
            myPMHandle.MTM;
        end
        function TCB_sendEmail(obj,event,recipient,subject)
            contextSingleton = EventContext.getInstance;
            myEMHandle = contextSingleton.myEmailManager;
            emailStr = Courrier.MO2str;
            myEMHandle.sendFromGmail(recipient, subject, emailStr);
        end
        function TCB_saveWorkspace(obj,event)
            contextSingleton = EventContext.getInstance;
            mySLMHandle = contextSingleton.mySaveLoadManager;
            mySLMHandle.saveWorkspace;
        end
        function TCB_reqHistData(obj,event,id,timeLengStr)
            disp('reqHistData');
            myIdMap = DataIdMap.getInstance;
            [ibContract,barDuraion,bidask,bartick] = myIdMap.id2details(id);
            
            endTime = datestr(clock,'yyyymmdd HH:MM:SS');
            % barDuraion is in the format '1 s', '2 s', '1 m', '2 m'
            % etc., has to be translated into '1 sec', '2 secs', '1 min',
            % '2 mins' etc.
            properBarDuraion = DateTimeUtils.intoProperStr(barDuraion);
            contextSingleton = EventContext.getInstance;
            contextSingleton.myIbHandle.reqHistoricalDataEx(id,ibContract,endTime,timeLengStr,properBarDuraion,bidask,1,1,contextSingleton.myIbHandle.createTagValueList);
        end
        function TCB_switchOff(obj)
            Galp.stop;
        end
    end
end