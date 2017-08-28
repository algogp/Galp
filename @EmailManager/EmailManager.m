%% Email Manager

classdef EmailManager < handle
    methods
        % Constructor
        function obj = EmailManager(varargin)
            % If no argument is passed in, use default (see properties)
            % Otherwise, use what the input argument suggests
            if nargin > 0
                obj.mySender = varargin{1}.sender;
                obj.myPassword = varargin{1}.password;
            end
        end
        function sendFromGmail(obj, recipient, subject, message)
            setpref('Internet','E_mail',obj.mySender);
            setpref('Internet','SMTP_Server','smtp.gmail.com');
            setpref('Internet','SMTP_Username',obj.mySender);
            setpref('Internet','SMTP_Password',obj.myPassword);

            props = java.lang.System.getProperties;
            props.setProperty('mail.smtp.auth','true');
            props.setProperty('mail.smtp.socketFactory.class', ...
                              'javax.net.ssl.SSLSocketFactory');
            props.setProperty('mail.smtp.socketFactory.port','465');

            sendmail(recipient, subject, message);
        end
    end
    properties
        % Login infos
        mySender;
        myPassword;
    end
end