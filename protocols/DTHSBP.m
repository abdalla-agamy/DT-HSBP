classdef DTHSBP < HSBP
    methods
        function obj = DTHSBP(swarm)
            obj@HSBP(swarm);
        end

        function initialize(obj)
            fprintf("DTHSBP initialized\n");
        end

        function result = join(obj,uavID,clusterID)
            cfg = obj.cfg;
            dtAdmissionTimer = tic;

            candidate = UAV(uavID,clusterID,cfg);
            candidate.dt.update();

            canJoin = StabilityModel.canJoin( ...
                candidate.dt.stabilityScore, cfg);

            dtAdmissionTime = toc(dtAdmissionTimer);

            if canJoin
                obj.swarm.clusters(clusterID).addUAV(candidate);
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

                result = obj.createRekeyResult(activeUAVs, clusterID);
                result.leaderTime = leaderTime;
                result.followerTime = followerTime;
                result.dtAdmissionTime = dtAdmissionTime;

                obj.addCost(cluster.count());
                obj.recordJoin();
            else
                result = [];
                fprintf("Join rejected by DT.\n");
            end
        end

        function result = leave(obj,uavID)
            uav = obj.swarm.findUAV(uavID);
            if isempty(uav)
                result = [];
                return;
            end

            cluster = obj.swarm.findCluster(uav.clusterID);
            predictedLeaves = obj.collectPredictedLeaves(cluster, uavID);

            for i = 1:numel(predictedLeaves)
                obj.swarm.removeUAV(predictedLeaves(i));
            end

            result = leave@HSBP(obj,uavID);

            if ~isempty(result)
                result.predictedLeaves = predictedLeaves;
            end
        end

        function result = failure(obj,uavID)
            uav = obj.swarm.findUAV(uavID);
            if isempty(uav)
                result = [];
                return;
            end

            if uav.dt.stabilityScore > obj.cfg.stabilityThreshold
                fprintf("DT detected Failed UAV %d\n",uav.id);
            end

            cluster = obj.swarm.findCluster(uav.clusterID);
            predictedLeaves = obj.collectPredictedLeaves(cluster, uavID);

            for i = 1:numel(predictedLeaves)
                obj.swarm.removeUAV(predictedLeaves(i));
            end

            result = failure@HSBP(obj,uavID);

            if ~isempty(result)
                result.predictedLeaves = predictedLeaves;
            end
        end
    end

    methods (Access = private)
        function predictedLeaves = collectPredictedLeaves(obj, cluster, excludedUAVID)
            predictedLeaves = [];
            if isempty(cluster)
                return;
            end

            members = cluster.getActiveUAVs();
            currentTime = obj.getCurrentTime(members);

            for i = 1:numel(members)
                candidate = members(i);
                if candidate.id == excludedUAVID
                    continue;
                end

                if candidate.dt.hasPredictedLeave(currentTime)
                    predictedLeaves(end+1) = candidate.id;
                    candidate.dt.consumePrediction();
                end
            end
        end

        function currentTime = getCurrentTime(obj, members)
            currentTime = 0;
            if isempty(members)
                return;
            end

            if isfield(obj.cfg,'currentTime')
                currentTime = obj.cfg.currentTime;
                return;
            end

            % Fallback for standalone controlled tests that call the
            % protocol directly without constructing Simulation.cfg time.
            candidate = members(1);
            if isfield(candidate.dt.cfg,'currentTime')
                currentTime = candidate.dt.cfg.currentTime;
            end
        end
    end
end
