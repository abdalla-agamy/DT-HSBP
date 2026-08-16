function result = runLeaveExperiment(protocolName, swarmSize, clusterID, runID, randomSeed)
%RUNLEAVEEXPERIMENT Execute one controlled instability-driven leave.
%
%   The same initial swarm, random seed, leave requester, and controlled
%   instability state are used for FlatSBP, HSBP, and DTHSBP.
%
%   One UAV requests leave. FlatSBP rekeys the whole swarm, HSBP rekeys
%   the requester's cluster, and DTHSBP additionally removes UAVs whose
%   DT stability score exceeds thetaLeave before performing one cluster
%   rekey.

    if nargin < 2
        error('runLeaveExperiment:InvalidArguments', ...
            'protocolName and swarmSize are required.');
    end

    if nargin < 3
        clusterID = 1;
    end

    if nargin < 4
        runID = 1;
    end

    if nargin < 5
        randomSeed = 42;
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

    %% Configuration

    cfg = config();
    cfg.numUAVs = swarmSize;
    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = randomSeed;
    rng(randomSeed);

    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('runLeaveExperiment:InvalidConfiguration', ...
            'swarmSize must be divisible by the number of clusters.');
    end

    if clusterID < 1 || clusterID > cfg.numClusters || ...
            mod(clusterID,1) ~= 0
        error('runLeaveExperiment:InvalidClusterID', ...
            'clusterID must be an integer from 1 to %d.', cfg.numClusters);
    end

    %% Build common initial swarm

    swarm = Swarm(cfg);

    %% Select protocol

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

    %% Prepare result

    result = ExperimentResult();
    result.protocol = string(protocolName);
    result.eventType = "Leave";
    result.runID = runID;
    result.randomSeed = randomSeed;
    result.swarmSize = swarm.totalUAVs();
    result.clusterCount = cfg.numClusters;
    result.clusterSize = cfg.clusterSize;
    result.eventCount = 1;

    %% Common controlled leave scenario
    %
    % UAV 4 is the explicit requester. UAVs 2 and 3 receive the same
    % controlled mobility disturbance used to create a DT prediction
    % residual. The state preparation is identical for every protocol;
    % only DTHSBP consumes the resulting DT stability information.

    leavingUAVID = 4;
    disturbedUAVIDs = [2 3];
    positionPerturbation = [10 0];

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
                'Disturbed UAV %d is not in cluster %d.', ...
                disturbedUAVIDs(i), clusterID);
        end

        % First update establishes the DT prediction.
        candidate.dt.update();

        % Controlled mobility divergence.
        candidate.position = candidate.position + positionPerturbation;

        % Second update computes the prediction residual/stability score.
        candidate.dt.update();
    end

    leavingUAV = swarm.findUAV(leavingUAVID);

    if isempty(leavingUAV) || leavingUAV.clusterID ~= clusterID
        result.success = false;
        result.status = "Failed";
        return;
    end

    %% Single common leave request

    rekeyResult = protocol.leave(leavingUAVID);

    %% Record outcome

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

    if isprop(rekeyResult, 'predictedLeaves') && ...
            ~isempty(rekeyResult.predictedLeaves)
        result.predictedLeaves = rekeyResult.predictedLeaves;
    end

    result.success = true;
    result.status = "Success";

end
