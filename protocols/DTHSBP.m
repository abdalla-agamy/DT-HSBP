% DTHSBP Digital Twin-Driven Hierarchical Scalable Batch Rekeying Protocol.
%
% Architecture & Contributions:
%   1. Collateral Batch Rekeying: Proactively groups impending departures
%      predicted by the Digital Twin into single atomic rekeying rounds.
%   2. Contribution A (Lifespan-Aware Diffie-Hellman Chain Sorting):
%      Dynamically sequences cluster members in descending order of remaining
%      mission lifespan, guaranteeing departing nodes cluster at the tail
%      and truncating intermediate chain recalculations from O(n_c) to O(1).
%   3. Contribution B:
%      Zero Cryptographic Application-Layer Transition Latency (eliminating
%      application-layer cryptographic stall times, distinct from physical
%      RF channel propagation and medium-access delays). Asynchronously
%      pre-computes intermediate DH chains, blind keys, and group keys before
%      flight transitions materialize.
%
% Evaluation Boundary Qualification:
%   The evaluation focuses strictly on mission broadcast rekeying overhead
%   within the operational channel, while Digital Twin telemetry is assumed
%   to utilize standard periodic supervisory datalinks (e.g., MAVLink
%   telemetry streams) with amortized background overhead.
%
classdef DTHSBP < HSBP

    properties
        precomputationEngine
    end

    methods
        function obj = DTHSBP(swarm)
            obj@HSBP(swarm);
            obj.precomputationEngine = DTPrecomputationEngine(obj.cfg, swarm, obj.engine);
        end

        function initialize(obj)
            fprintf("DTHSBP initialized\n");
        end

        function pkg = precompute(obj, uavID)
            pkg = obj.precomputationEngine.interceptPrediction(uavID);
        end

        function pkg = precomputeForCluster(obj, clusterID, departingIDs)
            if nargin < 3, departingIDs = []; end
            pkg = obj.precomputationEngine.precomputeForCluster(clusterID, departingIDs);
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
                activeUAVs = cluster.getSortedActiveUAVs();

                leaderTimer = tic;
                [newGroupKey, intermediateChain] = obj.engine.generateGroupKey(activeUAVs);
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
                result.intermediateChain = intermediateChain;

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

            clusterID = uav.clusterID;
            cluster = obj.swarm.findCluster(clusterID);

            % Capture pre-leave lifespan-sorted cluster state (tail contains leaving nodes)
            preSortedUAVs = cluster.getSortedActiveUAVs();

            predictedLeaves = obj.collectPredictedLeaves(cluster, uavID);
            allDepartingIDs = unique([uavID, predictedLeaves]);

            % Check precomputed key cache for zero cryptographic application-layer transition latency (Contribution B)
            cachedPackage = cluster.getPrecomputedKey(allDepartingIDs);

            for i = 1:numel(predictedLeaves)
                obj.swarm.removeUAV(predictedLeaves(i));
            end

            obj.swarm.removeUAV(uavID);

            % Obtain post-leave active UAVs sorted by lifespan
            activeUAVs = cluster.getSortedActiveUAVs();

            if ~isempty(activeUAVs)
                leaderTimer = tic;
                if ~isempty(cachedPackage)
                    newGroupKey = cachedPackage.groupKey;
                    intermediateChain = cachedPackage.intermediateChain;
                    blindKeys = cachedPackage.blindKeys;
                    isPrecomputedHit = true;
                    leaderTime = toc(leaderTimer); % Negligible cache retrieval time (~0)
                    cluster.clearPrecomputedKey();
                else
                    [newGroupKey, intermediateChain] = obj.engine.generateGroupKey(activeUAVs);
                    blindKeys = [];
                    isPrecomputedHit = false;
                    leaderTime = toc(leaderTimer);
                end

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
                result.predictedLeaves = predictedLeaves;
                result.preSortedUAVs = preSortedUAVs;
                result.intermediateChain = intermediateChain;
                result.isPrecomputedHit = isPrecomputedHit;
                result.blindKeys = blindKeys;
            else
                cluster.groupKey = [];
                result = [];
            end

            obj.addCost(cluster.count());
            obj.recordLeave();
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

            clusterID = uav.clusterID;
            cluster = obj.swarm.findCluster(clusterID);

            % Capture pre-failure lifespan-sorted cluster state
            preSortedUAVs = cluster.getSortedActiveUAVs();

            predictedLeaves = obj.collectPredictedLeaves(cluster, uavID);
            allDepartingIDs = unique([uavID, predictedLeaves]);

            % Check precomputed key cache for zero cryptographic application-layer transition latency (Contribution B)
            cachedPackage = cluster.getPrecomputedKey(allDepartingIDs);

            for i = 1:numel(predictedLeaves)
                obj.swarm.removeUAV(predictedLeaves(i));
            end

            obj.swarm.removeUAV(uavID);

            % Post-failure active UAVs sorted by lifespan
            activeUAVs = cluster.getSortedActiveUAVs();

            if ~isempty(activeUAVs)
                leaderTimer = tic;
                if ~isempty(cachedPackage)
                    newGroupKey = cachedPackage.groupKey;
                    intermediateChain = cachedPackage.intermediateChain;
                    blindKeys = cachedPackage.blindKeys;
                    isPrecomputedHit = true;
                    leaderTime = toc(leaderTimer);
                    cluster.clearPrecomputedKey();
                else
                    [newGroupKey, intermediateChain] = obj.engine.generateGroupKey(activeUAVs);
                    blindKeys = [];
                    isPrecomputedHit = false;
                    leaderTime = toc(leaderTimer);
                end

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
                result.predictedLeaves = predictedLeaves;
                result.preSortedUAVs = preSortedUAVs;
                result.intermediateChain = intermediateChain;
                result.isPrecomputedHit = isPrecomputedHit;
                result.blindKeys = blindKeys;
            else
                cluster.groupKey = [];
                result = [];
            end

            obj.addCost(cluster.count());
            obj.recordFailure();
        end

        function result = rekeyCluster(obj,clusterID)
            cluster = obj.swarm.findCluster(clusterID);
            if isempty(cluster)
                result = [];
                return;
            end

            activeUAVs = cluster.getSortedActiveUAVs();

            if ~isempty(activeUAVs)
                leaderTimer = tic;
                [newGroupKey, intermediateChain] = obj.engine.generateGroupKey(activeUAVs);
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
                result.intermediateChain = intermediateChain;
            else
                cluster.groupKey = [];
                result = [];
            end

            obj.addCost(cluster.count());
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
