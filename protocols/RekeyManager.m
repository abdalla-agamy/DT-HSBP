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
        function result = performLocalRekey(obj,cluster)

            activeUAVs = cluster.getActiveUAVs();

            result = obj.buildResult( ...
                activeUAVs, ...
                cluster.id);

        end

        %----------------------------------------------------------
        function result = buildResult( ...
                obj,affectedUAVs,clusterID)

            result = RekeyResult();

            result.clusterID = clusterID;

            result.affectedUAVs = affectedUAVs;

            result.numAffected = numel(affectedUAVs);

            result.keysGenerated = 1;

            result.messagesSent = result.numAffected;

            result.encryptions = result.numAffected;

            result.decryptions = result.numAffected;

            result.hashOperations = result.numAffected;

            result.randomNumbers = 1;

            obj.totalRekeys = obj.totalRekeys + 1;

        end
        %----------------------------------------------------------
        function n = getTotalRekeys(obj)

            n = obj.totalRekeys;

        end

    end

end