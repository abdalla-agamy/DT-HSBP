classdef HSBP < Protocol

    methods

        function obj = HSBP(swarm)

            obj@Protocol(swarm);

        end

        %--------------------------------------------

        function initialize(obj)

            fprintf("HSBP initialized\n");

        end

        %--------------------------------------------

        function join(obj,clusterID)

            uavID = obj.swarm.allocateUAVID();

            obj.swarm.addUAV(uavID,clusterID);

            cluster = obj.swarm.findCluster(clusterID);

            activeUAVs = cluster.getActiveUAVs();

            newGroupKey = obj.engine.generateGroupKey(activeUAVs);

            cluster.groupKey = newGroupKey;

            for i = 1:numel(activeUAVs)

                activeUAVs(i).groupKey = newGroupKey;
                activeUAVs(i).keySynced = true;

            end

            obj.addCost(cluster.count());

            obj.recordJoin();

        end

        %--------------------------------------------

        function leave(obj,uavID)

            u = obj.swarm.findUAV(uavID);

            if isempty(u)
                return;
            end

            clusterID = u.clusterID;

            obj.swarm.removeUAV(uavID);

            cluster = obj.swarm.findCluster(clusterID);

            activeUAVs = cluster.getActiveUAVs();

            if ~isempty(activeUAVs)

                newGroupKey = obj.engine.generateGroupKey(activeUAVs);

                cluster.groupKey = newGroupKey;

                for i = 1:numel(activeUAVs)

                    activeUAVs(i).groupKey = newGroupKey;
                    activeUAVs(i).keySynced = true;

                end

            else

                cluster.groupKey = [];

            end

            obj.addCost(cluster.count());

            obj.recordLeave();

        end

        %--------------------------------------------

        function failure(obj,uavID)

            u = obj.swarm.findUAV(uavID);

            if isempty(u)
                return;
            end

            clusterID = u.clusterID;

            obj.swarm.removeUAV(uavID);

            cluster = obj.swarm.findCluster(clusterID);

            activeUAVs = cluster.getActiveUAVs();

            if ~isempty(activeUAVs)

                newGroupKey = obj.engine.generateGroupKey(activeUAVs);

                cluster.groupKey = newGroupKey;

                for i = 1:numel(activeUAVs)

                    activeUAVs(i).groupKey = newGroupKey;
                    activeUAVs(i).keySynced = true;

                end

            else

                cluster.groupKey = [];

            end

            obj.addCost(cluster.count());

            obj.recordFailure();

        end

    end

end