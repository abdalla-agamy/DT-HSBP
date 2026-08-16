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

        function result = join(obj,uavID,clusterID)

            obj.swarm.addUAV(uavID,clusterID);

            cluster = obj.swarm.findCluster(clusterID);

            activeUAVs = cluster.getActiveUAVs();

            leaderTimer = tic;
            newGroupKey = obj.engine.generateGroupKey(activeUAVs);
            leaderTime = toc(leaderTimer);

            cluster.groupKey = newGroupKey;

            followerTimer = tic;
            for i = 1:numel(activeUAVs)

                activeUAVs(i).groupKey = newGroupKey;
                activeUAVs(i).keySynced = true;

            end
            followerTime = toc(followerTimer);

            result = obj.createRekeyResult( ...
                activeUAVs, ...
                clusterID);

            result.leaderTime = leaderTime;
            result.followerTime = followerTime;

            obj.addCost(cluster.count());

            obj.recordJoin();

        end

        %--------------------------------------------

        function result = leave(obj,uavID)

            u = obj.swarm.findUAV(uavID);

            if isempty(u)
                result = [];
                return;
            end

            clusterID = u.clusterID;

            obj.swarm.removeUAV(uavID);

            cluster = obj.swarm.findCluster(clusterID);

            activeUAVs = cluster.getActiveUAVs();

            if ~isempty(activeUAVs)

                leaderTimer = tic;
                newGroupKey = obj.engine.generateGroupKey(activeUAVs);
                leaderTime = toc(leaderTimer);

                cluster.groupKey = newGroupKey;

                followerTimer = tic;
                for i = 1:numel(activeUAVs)

                    activeUAVs(i).groupKey = newGroupKey;
                    activeUAVs(i).keySynced = true;

                end
                followerTime = toc(followerTimer);

                result = obj.createRekeyResult( ...
                    activeUAVs, ...
                    clusterID);

                result.leaderTime = leaderTime;
                result.followerTime = followerTime;

            else

                cluster.groupKey = [];
                result = [];

            end

            obj.addCost(cluster.count());

            obj.recordLeave();

        end

        %--------------------------------------------

        function result = failure(obj,uavID)

            u = obj.swarm.findUAV(uavID);

            if isempty(u)
                result = [];
                return;
            end

            clusterID = u.clusterID;

            obj.swarm.removeUAV(uavID);

            cluster = obj.swarm.findCluster(clusterID);

            activeUAVs = cluster.getActiveUAVs();

            if ~isempty(activeUAVs)

                leaderTimer = tic;
                newGroupKey = obj.engine.generateGroupKey(activeUAVs);
                leaderTime = toc(leaderTimer);

                cluster.groupKey = newGroupKey;

                followerTimer = tic;
                for i = 1:numel(activeUAVs)

                    activeUAVs(i).groupKey = newGroupKey;
                    activeUAVs(i).keySynced = true;

                end
                followerTime = toc(followerTimer);

                result = obj.createRekeyResult( ...
                    activeUAVs, ...
                    clusterID);

                result.leaderTime = leaderTime;
                result.followerTime = followerTime;

            else

                cluster.groupKey = [];
                result = [];

            end

            obj.addCost(cluster.count());

            obj.recordFailure();

        end

    end

end
