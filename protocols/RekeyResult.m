classdef RekeyResult

    properties

        %----------------------------------------------------------
        % Rekey information
        %----------------------------------------------------------
        clusterID

        affectedUAVs

        %----------------------------------------------------------
        % Metrics
        %----------------------------------------------------------
        numAffected = 0

        keysGenerated = 0

        messagesSent = 0

        encryptions = 0

    end

end