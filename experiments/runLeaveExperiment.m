function result = runLeaveExperiment(protocolName, swarmSize, clusterID, runID, randomSeed, leavingUAVID, disturbedUAVIDs, positionPerturbation)
%RUNLEAVEEXPERIMENT Execute one controlled instability-driven leave.
%
%   The same initial swarm, random seed, leave requester, and controlled
%   instability state are used for FlatSBP, HSBP, and DTHSBP.
%
%   One UAV requests leave. The supplied disturbed UAVs receive the same
%   controlled mobility disturbance used to create DT prediction residuals.
%   DTHSBP consumes the resulting DT stability information before performing
%   the cluster-local leave operation.
%
%   LEAVINGUAVID, DISTURBEDUAVIDS, and POSITIONPERTURBATION are optional and
%   are used by the stochastic Join/Leave performance layer to randomize the
%   workload episode while preserving the validated DT mechanism.

    if nargin < 2
        error('runLeaveExperiment:InvalidArguments', ...
            'protocolName and swarmSize are required.');
    end

    if nargin < 3, clusterID = 1; end
    if nargin < 4, runID = 1; end
    if nargin < 5, randomSeed = 42; end

    cfg = config();
    cfg.numUAVs = swarmSize;
    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = randomSeed;
    rng(randomSeed);

    if nargin < 6 || isempty(leavingUAVID)
        leavingUAVID = clusterID * cfg.clusterSize;
    end
    if nargin < 7 || isempty(disturbedUAVIDs)
        disturbedUAVIDs = [leavingUAVID - 2, leavingUAVID - 1];
    end
    if nargin < 8 || isempty(positionPerturbation)
        positionPerturbation = [10 0];
    end

    if swarmSize < 1 || mod(swarmSize,1) ~= 0
        error('runLeaveExperiment:InvalidSwarmSize', ...
            'swarmSize must be a positive integer.');
    end
    if runID < 1 || mod(runID,1) ~= 0
        error('runLeaveExperiment:InvalidRunID', ...
            'runID must be a positive integer.');
    end
    if randomSeed < 0 || mod(randomSeed,1) ~= 0
        error('runLeaveExperiment:InvalidRandomSeed', ...
            'randomSeed must be a non-negative integer.');
    end
    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('runLeaveExperiment:InvalidConfiguration', ...
            'swarmSize must be divisible by the number of clusters.');
    end
    if clusterID < 1 || clusterID > cfg.numClusters || mod(clusterID,1) ~= 0
        error('runLeaveExperiment:InvalidClusterID', ...
            'clusterID must be an integer from 1 to %d.', cfg.numClusters);
    end

    clusterStart = (clusterID - 1) * cfg.clusterSize + 1;
    clusterEnd = clusterID * cfg.clusterSize;
    if leavingUAVID < clusterStart || leavingUAVID > clusterEnd || ...
            mod(leavingUAVID,1) ~= 0
        error('runLeaveExperiment:InvalidLeavingUAV', ...
            'leavingUAVID must belong to cluster %d.', clusterID);
    end
    disturbedUAVIDs = disturbedUAVIDs(:)';
    if isempty(disturbedUAVIDs) || any(mod(disturbedUAVIDs,1) ~= 0) || ...
            any(disturbedUAVIDs < clusterStart) || any(disturbedUAVIDs > clusterEnd) || ...
            numel(unique(disturbedUAVIDs)) ~= numel(disturbedUAVIDs) || ...
            any(disturbedUAVIDs == leavingUAVID)
        error('runLeaveExperiment:InvalidDisturbedUAVs', ...
            'All disturbed UAVs must be unique, belong to cluster %d, and differ from the leaving UAV.', clusterID);
    end
    if numel(positionPerturbation) ~= 2 || any(~isfinite(positionPerturbation))
        error('runLeaveExperiment:InvalidPerturbation', ...
            'positionPerturbation must be a finite 1-by-2 vector.');
    end

    swarm = Swarm(cfg);

    switch string(protocolName)
        case "DTHSBP"
            protocol = DTHSBP(swarm);
        case "HSBP"
            protocol = HSBP(swarm);
        case "FlatSBP"
            protocol = FlatSBP(swarm);
        otherwise
            error('runLeaveExperiment:UnknownProtocol', ...
                'Unknown protocol: %s', string(protocolName));
    end

    result = ExperimentResult();
    result.protocol = string(protocolName);
    result.eventType = "Leave";
    result.runID = runID;
    result.randomSeed = randomSeed;
    result.swarmSize = swarm.totalUAVs();
    result.clusterCount = cfg.numClusters;
    result.clusterSize = cfg.clusterSize;
    result.eventCount = 1;

    cluster = swarm.findCluster(clusterID);
    if isempty(cluster)
        result.success = false;
        result.status = "Failed";
        return;
    end

    for i = 1:numel(disturbedUAVIDs)
        candidate = swarm.findUAV(disturbedUAVIDs(i));
        if isempty(candidate) || candidate.clusterID ~= clusterID
            error('runLeaveExperiment:InvalidDisturbedUAV', ...
                'Disturbed UAV %d is not in cluster %d.', disturbedUAVIDs(i), clusterID);
        end
        candidate.dt.update();
        candidate.position = candidate.position + positionPerturbation;
        candidate.dt.update();
    end

    leavingUAV = swarm.findUAV(leavingUAVID);
    if isempty(leavingUAV) || leavingUAV.clusterID ~= clusterID
        result.success = false;
        result.status = "Failed";
        return;
    end

    rekeyResult = protocol.leave(leavingUAVID);
    if isempty(rekeyResult)
        result.success = false;
        result.status = "Rejected";
        return;
    end

    result.rekeyCount = 1;
    result.leaderTime = rekeyResult.leaderTime;
    result.followerTime = rekeyResult.followerTime;
    result.messageCount = rekeyResult.messagesSent;
    result.messageBytes = rekeyResult.messagesSent * cfg.messageSize;

    if isprop(rekeyResult, 'predictedLeaves') && ~isempty(rekeyResult.predictedLeaves)
        result.predictedLeaves = rekeyResult.predictedLeaves;
    end

    result.success = true;
    result.status = "Success";
end
