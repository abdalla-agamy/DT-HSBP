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

        %----------------------------------------------------------
        % Execution timing
        %----------------------------------------------------------
        leaderTime = 0

        followerTime = 0

        % DT-specific admission timing. Zero for non-DT protocols.
        dtAdmissionTime = 0

    end

end
