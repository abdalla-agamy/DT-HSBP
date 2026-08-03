classdef RekeyManager < handle

    properties (Access = private)

        cfg

        totalRekeys = 0

    end

    methods

        function obj = RekeyManager(cfg)

            obj.cfg = cfg;

        end

        %----------------------------------------------------------
        function result = performLocalRekey(obj, cluster)

            %--------------------------------------------------------------
            % Create result object
            %--------------------------------------------------------------
            result = RekeyResult();

            result.clusterID = cluster.id;

            %--------------------------------------------------------------
            % Determine affected UAVs
            %--------------------------------------------------------------
            activeUAVs = cluster.getActiveUAVs();

            result.affectedUAVs = activeUAVs;

            result.numAffected = numel(activeUAVs);

            %--------------------------------------------------------------
            % Protocol metrics
            %--------------------------------------------------------------
            result.keysGenerated = 1;

            result.messagesSent = result.numAffected;

            result.encryptions = result.numAffected;

            result.decryptions = result.numAffected;

            result.hashOperations = result.numAffected;

            result.randomNumbers = 1;

            %--------------------------------------------------------------
            % Internal statistics
            %--------------------------------------------------------------
            obj.totalRekeys = obj.totalRekeys + 1;

        end

        %----------------------------------------------------------
        function n = getTotalRekeys(obj)

            n = obj.totalRekeys;

        end

    end

end