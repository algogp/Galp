%% Courrier
% Responsible for transporting info between back office (i.e.
% SaveLoadManager, EmailManager, etc.) and middle office (i.e.
% OrderManager, PortfolioManager, etc.)

classdef Courrier
    methods (Static)
        % Transporting info from MO to file
        function MO2file()
            % TBD
        end

        % Transporting info from MO to string
        function strOutput = MO2str()
            contextSingleton = EventContext.getInstance;
            myPMHandle = contextSingleton.myPortfolioManager;
            
            %% Get portfolio data fields from PortfolioManager
            [fieldNameArr, outputArr] = myPMHandle.getAllAccountFields;
            strOutput = ['___________________________' char(10) 'Portfolio Information' ...
                char(10) '___________________________' char(10)];
            
            % Construct string (char(10) is new line)
            for i = 1:length(fieldNameArr) % Totally 16 fields in PortfolioManager
                strOutput = [strOutput char(10) fieldNameArr{1,i} ' ' outputArr{1,i} char(10)];
            end
            
            %% Get strategy-specific info from PortfolioManager
            strOutput = [strOutput char(10) '___________________________' char(10) ...
                'PnL by Combo' char(10) '___________________________' char(10)];
            for i = 1:myPMHandle.numActiveCombo
                [stratName, comboId, unitHeld, entryPrice, realizedPnL, unrealizedPnL] = myPMHandle.readCombo(i);
				if unrealizedPnL >= 0
					signStr = ' +';
				else
					signStr = ' ';
				end
                strOutput = [strOutput char(10) myPMHandle.ComboHolding2DArr{1,i} '    ' ...
                    'Combo:    ' num2str(comboId) '    ' ...
                    'Amount:    ' num2str(unitHeld) '    ' ...
                    'PnL:    ' num2str(realizedPnL) signStr num2str(unrealizedPnL) char(10)];
            end
            
            %% Get security position info from PortfolioManager
            strOutput = [strOutput char(10) '___________________________' char(10) ...
                'Amount Held' char(10) '___________________________' char(10)];
            for i = 1:myPMHandle.numHoldingPosition
                [holdingSymbol, holdingPosition] = myPMHandle.readSec(i);
                strOutput = [strOutput char(10) holdingSymbol '    ' ...
                    'Amount:    ' num2str(holdingPosition) char(10)];
            end
%             GeneralUtils.logWrapper(['Courrier::MO2str: Number of holdings = ' num2str(size(myPMHandle.secHoldings2DArr_old,2))]);
        end
        
        % Transporting info from portfolio info to matrix
        function matOutput = portInfo2mat()
            contextSingleton = EventContext.getInstance;
            myPMHandle = contextSingleton.myPortfolioManager;
            
            % Get portfolio data fields from PortfolioManager
            [fieldNameArr, outputArr] = myPMHandle.getAllAccountFields;
            matOutput = [fieldNameArr', outputArr'];
        end
        
        % Transporting info from strategy info to matrix
        function matOutput = stratInfo2mat()
            contextSingleton = EventContext.getInstance;
            myPMHandle = contextSingleton.myPortfolioManager;
            
            stratNameArr = cell(1,myPMHandle.numActiveCombo);
            comboNameArr = cell(1,myPMHandle.numActiveCombo);
            amountArr = cell(1,myPMHandle.numActiveCombo);
            PnLArr = cell(1,myPMHandle.numActiveCombo);
            % Get strategy-specific info from PortfolioManager
            for i = 1:myPMHandle.numActiveCombo
                [stratName, comboId, unitHeld, entryPrice, realizedPnL, unrealizedPnL] = myPMHandle.readCombo(i);
                stratNameArr{1,i} = stratName;
                comboNameArr{1,i} = comboId;
                amountArr{1,i} = unitHeld;
                PnLArr{1,i} = realizedPnL;
            end
            matOutput = [stratNameArr', comboNameArr', amountArr', PnLArr'];
        end
        
        % Transporting info from security holding info to matrix
        function matOutput = secHoldingInfo2mat()
            contextSingleton = EventContext.getInstance;
            myPMHandle = contextSingleton.myPortfolioManager;
            
            secNameArr = cell(1,myPMHandle.numHoldingPosition);
            amountArr = cell(1,myPMHandle.numHoldingPosition);
            for i = 1:myPMHandle.numHoldingPosition
                [holdingSymbol, holdingPosition] = myPMHandle.readSec(i);
                secNameArr{1,i} = holdingSymbol;
                amountArr{1,i} = holdingPosition;
            end
            matOutput = [secNameArr', amountArr'];
        end
        
        % Transporting info from file to MO
        function file2MO()
            % TBD
        end
        
        % Gather data from either SaveLoadManager or MO
        function gatherData(fromWhere)
            
        end
    end
    properties
        
    end
end