classdef (ConstructOnLoad) ToggleEventData < event.EventData
    properties
        message
    end
    
    methods
        function data = ToggleEventData(message)
            data.message = message;
        end
    end
end