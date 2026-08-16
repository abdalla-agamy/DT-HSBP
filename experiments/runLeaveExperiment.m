function result = runLeaveExperiment(protocolName, swarmSize, clusterID)
%RUNLEAVEEXPERIMENT Execute one controlled leave experiment.
%
%   RESULT = RUNLEAVEEXPERIMENT(PROTOCOLNAME, SWARMSIZE, CLUSTERID)
%   creates a swarm, selects one deterministic non-leader UAV from the
%   requested cluster, executes exactly one controlled leave request, and
%   returns the collected experiment result.
%
%   No stochastic event generation is used here.

    if nargin < 2
        error('runLeaveExperiment:InvalidArguments', ...
            'protocolName and swarmSize are required.');
    end

    if nargin < 3
        clusterID = 1;
    end

    if swarmSize < 1 || mod(swarmSize,1) ~= 0
        error('runLeaveExperiment:InvalidSwarmSize', ...
            'swarmSize must be a positive integer.');
    end

    %% Configuration

    cfg = config();

    cfg.numUAVs = swarmSize;
    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;

    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('runLeaveExperiment:InvalidConfiguration', ...
            'swarmSize must be divisible by the number of clusters.');
    end

    if clusterID < 1 || clusterID > cfg.numClusters || ...
            mod(clusterID,1) ~= 0
        error('runLeaveExperiment:InvalidClusterID', ...
            'clusterID must be an integer from 1 to %d.', cfg.numClusters);
    end

    %% Build swarm

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

    result.runID = 1;
    result.randomSeed = cfg.randomSeed;

    result.swarmSize = swarm.totalUAVs();
    result.clusterCount = cfg.numClusters;
    result.clusterSize = cfg.clusterSize;

    result.eventCount = 1;

    %% Select deterministic non-leader UAV

    cluster = swarm.findCluster(clusterID);
    activeUAVs = cluster.getActiveUAVs();

    leavingUAV = [];

    for i = 1:numel(activeUAVs)

        if activeUAVs(i).id ~= swarm.leader.id
            leavingUAV = activeUAVs(i);
            break;
        end

    end

    if isempty(leavingUAV)
        error('runLeaveExperiment:NoValidUAV', ...
            'No non-leader active UAV is available in cluster %d.', ...
            clusterID);
    end

    %% Controlled leave

    rekeyResult = protocol.leave(leavingUAV.id);

    %% Record outcome

    if isempty(rekeyResult)
        return;
    end

    result.rekeyCount = 1;

    result.leaderTime = rekeyResult.leaderTime;
    result.followerTime = rekeyResult.followerTime;

    result.messageCount = rekeyResult.messagesSent;
    result.messageBytes = ...
        rekeyResult.messagesSent * cfg.messageSize;

    if ~isempty(rekeyResult.predictedLeaves)
        result.predictedLeaves = rekeyResult.predictedLeaves;
    end

end
