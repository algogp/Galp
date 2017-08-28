%% Save Load Manager

classdef (Sealed) SaveLoadManager < handle
    methods (Access = private)
        % Constructor
        function obj = SaveLoadManager(varargin)
            if nargin > 0
                obj.myFileName = varargin{1}{1}.fileName;
                obj.myPathName = varargin{1}{1}.pathName;
            end
        end
    end
    methods (Static)
        function singleObj = getInstance(varargin)
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = SaveLoadManager(varargin);
            end
            singleObj = localObj;
        end
    end
    methods
        function saveWorkspace(obj)
            % Save only the PortfolioManager
            contextSingleton = EventContext.getInstance;
            PMTemp = contextSingleton.myPortfolioManager;
            fullPath = strcat(obj.myPathName, ...
                              obj.myFileName, ...
                              datestr(clock,'yyyymmddHHMMSS'),'.mat');
            save(fullPath,'PMTemp');
        end
        function loadPositions(obj,inputName)
            % inputName should be either: 
            % - 'xxx.mat' (load from matlab data file), or
            % - 'xxx.xlsx' (load from Excel file), or
            inputStrLeng = length(inputName);
            if strcmp(inputName(inputStrLeng-2:inputStrLeng),'mat')
                % Load from mat file
                var_temp = load(strcat(obj.myPathName,inputName));
                PMtemp = var_temp.PMTemp;
                readFromLoaded(PMtemp);
            elseif strcmp(inputName(inputStrLeng-3:inputStrLeng),'xlsx')
                % Load from Excel file
                readFromExcel(excelFileName);
            end
        end
    end
    methods (Access = private)
        function readFromExcel(obj,excelFileName)
            % Should have in each row:
            % StratName, ComboId, ComboHolding, RealizedPnL
            [num, txt, raw] = xlsread(excelFileName);
            numPosition = size(raw,1);
            % To be implemented
        end
        function readFromLoaded(obj,PMTemp)
            % Read and add portfolio manager data from another EventContext
            % object (that might be from an external file)
            
            % NOTE: Currently we do not support appending to/consolidating into
            % existing context (in other words whenever this function is
            % called, the old context data will be overwritten)
            contextSingleton = EventContext.getInstance;
            myPMHandle = contextSingleton.myPortfolioManager;
            % Copy contract data
            for i = 1:length(PMTemp.mktdataContractDetails_internal)
                % Reconstruct contract
                contract = GeneralUtils.makeIbDelta1Contract(contextSingleton.myIbHandle, ...
                        PMTemp.mktdataContractDetails_internal{1,i}.symbol, ...
                        PMTemp.mktdataContractDetails_internal{1,i}.secType, ...
                        PMTemp.mktdataContractDetails_internal{1,i}.exchange, ...
                        PMTemp.mktdataContractDetails_internal{1,i}.currency);
                position = PMTemp.mktdataPosition_internal{1,i};
                
                myPMHandle.registerContractTrade(contract,position);
            end
            % Copy combo data
            for numStratCount = 1:length(PMTemp.stratContractDetailsArrArr)
                stratContractDetailsArr = PMTemp.stratContractDetailsArrArr{1,numStratCount};
                for j = 1:length(stratContractDetailsArr)
                    % Reconstruct contract
                    contractArr{1,j} = GeneralUtils.makeIbDelta1Contract(contextSingleton.myIbHandle, ...
                        stratContractDetailsArr{1,j}.symbol, ...
                        stratContractDetailsArr{1,j}.secType, ...
                        stratContractDetailsArr{1,j}.exchange, ...
                        stratContractDetailsArr{1,j}.currency);
                end
                
                strategyName = PMTemp.ComboHolding2DArr{1,numStratCount};
                
                comboId = PMTemp.ComboHolding2DArr{2,numStratCount};
                
                comboDef = PMTemp.stratComboDefArrArr{1,numStratCount};
                
                for numEntryCount = 1:length(PMTemp.comboEntryUnitArrArr{1,numStratCount})
                    % One combo can be traded multiple times, have to loop
                    % through all
                    comboUnit = PMTemp.comboEntryUnitArrArr{1,numStratCount}{1,numEntryCount};

                    comboEntryPrice = PMTemp.comboEntryPriceArrArr{1,numStratCount}{1,numEntryCount};
                    
                    % Register combo
                    myPMHandle.registerComboTrade(strategyName,comboId,comboUnit, ...
                                comboDef,contractArr,comboEntryPrice);
                end
            end
        end
	end
    properties
        myFileName;
        myPathName;
    end
end