classdef DTPrecomputationEngine < handle
    %DTPRECOMPUTATIONENGINE Predictive pre-calculation engine for zero-latency handover.
    %
    % This engine intercepts DT prediction events from DigitalTwinManager or
    % individual UAVs and asynchronously pre-calculates the expected
    % post-departure intermediate Diffie-Hellman key chains I_i^{t+1},
    % blind keys g^{I_i^{t+1}} mod p, and group key material before
    % flight transitions / departure events materialize.
    %
    % Pre-computed key packages are stored in cluster.precomputedKeyCache.
    % When DTHSBP.leave() executes, the key material is retrieved from the
    % cache with near-zero leader latency.

    properties
        cfg
        swarm
        engine
        totalPrecomputations = 0
    end

    methods

        function obj = DTPrecomputationEngine(cfg, swarm, engine)
            obj.cfg = cfg;
            obj.swarm = swarm;
            if nargin >= 3 && ~isempty(engine)
                obj.engine = engine;
            else
                obj.engine = SBPEngine(cfg);
            end
        end

        %----------------------------------------------------------
        function package = precomputeForCluster(obj, clusterID, departingIDs)
            %PRECOMPUTEFORCLUSTER Pre-computes group key and DH chains
            % for a cluster given a set of expected departing UAVs.

            if nargin < 3
                departingIDs = [];
            end

            cluster = obj.swarm.findCluster(clusterID);
            if isempty(cluster)
                package = [];
                return;
            end

            % Get current active members sorted by lifespan
            activeMembers = cluster.getSortedActiveUAVs();
            if isempty(activeMembers)
                package = [];
                return;
            end

            % If no specific departing IDs given, find predicted unstable members
            if isempty(departingIDs)
                for i = 1:numel(activeMembers)
                    u = activeMembers(i);
                    if ~isempty(u.dt) && (u.dt.predictedLeave || ...
                            u.dt.stabilityScore > obj.cfg.thetaLeave)
                        departingIDs(end+1) = u.id;
                    end
                end
            end
            departingIDs = unique(departingIDs);

            % Hypothetical remaining active UAVs after departure
            remainingMask = ~ismember([activeMembers.id], departingIDs);
            remainingUAVs = activeMembers(remainingMask);

            if isempty(remainingUAVs)
                package = [];
                return;
            end

            % Pre-compute intermediate DH chain and group key for survivors
            [groupKey, intermediateChain] = obj.engine.generateGroupKey(remainingUAVs);

            % Pre-compute blind keys: g^(intermediateChain_k) mod p
            g = obj.cfg.generator;
            p = obj.cfg.prime;
            blindKeys = zeros(1, numel(intermediateChain));
            for k = 1:numel(intermediateChain)
                blindKeys(k) = powermod(g, intermediateChain(k), p);
            end

            % Assemble package
            package.clusterID = clusterID;
            package.departingIDs = departingIDs;
            package.remainingIDs = [remainingUAVs.id];
            package.groupKey = groupKey;
            package.intermediateChain = intermediateChain;
            package.blindKeys = blindKeys;
            package.timestamp = 0;
            if isfield(obj.cfg, 'currentTime')
                package.timestamp = obj.cfg.currentTime;
            end

            % Cache in cluster
            cluster.precomputedKeyCache = package;
            obj.totalPrecomputations = obj.totalPrecomputations + 1;
        end

        %----------------------------------------------------------
        function package = interceptPrediction(obj, uavID)
            %INTERCEPTPREDICTION Intercepts an individual UAV prediction event.

            uav = obj.swarm.findUAV(uavID);
            if isempty(uav)
                package = [];
                return;
            end

            cluster = obj.swarm.findCluster(uav.clusterID);
            if isempty(cluster)
                package = [];
                return;
            end

            % Collect this UAV and any other predicted departing members in the cluster
            activeMembers = cluster.getActiveUAVs();
            departingIDs = uavID;
            for i = 1:numel(activeMembers)
                cand = activeMembers(i);
                if cand.id ~= uavID && ~isempty(cand.dt) && ...
                   (cand.dt.predictedLeave || cand.dt.stabilityScore > obj.cfg.thetaLeave)
                    departingIDs(end+1) = cand.id;
                end
            end

            package = obj.precomputeForCluster(uav.clusterID, unique(departingIDs));
        end

        %----------------------------------------------------------
        function count = interceptAllPredictions(obj, ~)
            %INTERCEPTALLPREDICTIONS Scans all clusters for predicted leaves and precomputes.

            count = 0;
            if isempty(obj.swarm)
                return;
            end

            for c = 1:numel(obj.swarm.clusters)
                cluster = obj.swarm.clusters(c);
                activeMembers = cluster.getActiveUAVs();
                predictedIDs = [];
                for i = 1:numel(activeMembers)
                    u = activeMembers(i);
                    if ~isempty(u.dt) && ...
                       (u.dt.predictedLeave || u.dt.stabilityScore > obj.cfg.thetaLeave)
                        predictedIDs(end+1) = u.id;
                    end
                end

                if ~isempty(predictedIDs)
                    obj.precomputeForCluster(cluster.id, unique(predictedIDs));
                    count = count + 1;
                end
            end
        end

    end

end
