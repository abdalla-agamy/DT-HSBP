classdef FlatSBP < Protocol

    methods

        function obj = FlatSBP(swarm)

            obj@Protocol(swarm);

        end

        %-----------------------------------

        function initialize(obj)

            fprintf("FlatSBP initialized\n");

        end

        %-----------------------------------

        function result = join(obj,uavID,clusterID)

            obj.swarm.addUAV(uavID,clusterID);

            allUAVs = obj.swarm.getActiveUAVs();

            leaderTimer = tic;
            newGroupKey = obj.engine.generateGroupKey(allUAVs);
            leaderTime = toc(leaderTimer);

            followerTimer = tic;
            for i = 1:numel(allUAVs)

                allUAVs(i).groupKey = newGroupKey;
                allUAVs(i).keySynced = true;

            end
            followerTime = toc(followerTimer);

            result = obj.createRekeyResult(allUAVs,[]);

            result.leaderTime = leaderTime;
            result.followerTime = followerTime;

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordJoin();

        end

        %-----------------------------------

        function result = leave(obj,uavID)

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)
                result = [];
                return;
            end

            obj.swarm.removeUAV(uavID);

            allUAVs = obj.swarm.getActiveUAVs();

            if ~isempty(allUAVs)

                leaderTimer = tic;
                newGroupKey = obj.engine.generateGroupKey(allUAVs);
                leaderTime = toc(leaderTimer);

                followerTimer = tic;
                for i = 1:numel(allUAVs)

                    allUAVs(i).groupKey = newGroupKey;
                    allUAVs(i).keySynced = true;

                end
                followerTime = toc(followerTimer);

                result = obj.createRekeyResult(allUAVs,[]);

                result.leaderTime = leaderTime;
                result.followerTime = followerTime;

            else

                result = [];

            end

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordLeave();

        end

        %-----------------------------------

        function result = failure(obj,uavID)

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)
                result = [];
                return;
            end

            obj.swarm.removeUAV(uavID);

            allUAVs = obj.swarm.getActiveUAVs();

            if ~isempty(allUAVs)

                leaderTimer = tic;
                newGroupKey = obj.engine.generateGroupKey(allUAVs);
                leaderTime = toc(leaderTimer);

                followerTimer = tic;
                for i = 1:numel(allUAVs)

                    allUAVs(i).groupKey = newGroupKey;
                    allUAVs(i).keySynced = true;

                end
                followerTime = toc(followerTimer);

                result = obj.createRekeyResult(allUAVs,[]);

                result.leaderTime = leaderTime;
                result.followerTime = followerTime;

            else

                result = [];

            end

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordFailure();

        end

    end

end
