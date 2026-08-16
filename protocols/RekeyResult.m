classdef RekeyResult

    properties

        %----------------------------------------------------------
        % Rekey information
        %----------------------------------------------------------
        clusterID

        affectedUAVs

        predictedLeaves

        %----------------------------------------------------------
        % Metrics
        %----------------------------------------------------------
        numAffected = 0

        keysGenerated = 0

        messagesSent = 0

        encryptions = 0
        %----------------------------------------------------------
        % Cryptographic Operations
        %----------------------------------------------------------
        decryptions = 0

        hashOperations = 0

        randomNumbers = 0

    end

end