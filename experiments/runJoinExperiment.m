function result = runJoinExperiment(protocolName, swarmSize, clusterID)
%RUNJOINEXPERIMENT Execute one controlled join experiment.
%
%   RESULT = RUNJOINEXPERIMENT(PROTOCOLNAME, SWARMSIZE, CLUSTERID)
%   creates a swarm, executes exactly one controlled join request, and
%   returns the collected experiment result.
%
%   No stochastic event generation is used here.

    if nargin < 2
        error('runJoinExperiment:InvalidArguments', ...
            'protocolName and swarmSize are required.');
    end

    if nargin < 3
        clusterID = 1;
    end

    if swarmSize < 1 || mod(swarmSize,1) ~= 0
        error('runJoinExperiment:InvalidSwarmSize', ...
            'swarmSize must be a positive integer.');
    end

    %% Configuration

    cfg = config();

    cfg.numUAVs = swarmSize;
    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;

    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('runJoinExperiment:InvalidConfiguration', ...
            'swarmSize must be divisible by the number of clusters.');
    end

    if clusterID < 1 || clusterID > cfg.numClusters || ...
            mod(clusterID,1) ~= 0
        error('runJoinExperiment:InvalidClusterID', ...
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
            error('runJoinExperiment:UnknownProtocol', ...
                'Unknown protocol: %s', string(protocolName));

    end

    %% Prepare result

    result = ExperimentResult();

    result.protocol = string(protocolName);
    result.eventType = "Join";

    result.runID = 1;
    result.randomSeed = cfg.randomSeed;

    result.swarmSize = swarm.totalUAVs();
    result.clusterCount = cfg.numClusters;
    result.clusterSize = cfg.clusterSize;

    result.eventCount = 1;

    %% Controlled join

    joiningUAVID = swarm.allocateUAVID();

    rekeyResult = protocol.join(joiningUAVID, clusterID);

    %% Record outcome

    if isempty(rekeyResult)

        result.rejectedJoins = 1;

    else

        result.acceptedJoins = 1;
        result.rekeyCount = 1;

        result.leaderTime = rekeyResult.leaderTime;
        result.followerTime = rekeyResult.followerTime;

        result.messageCount = rekeyResult.messagesSent;
        result.messageBytes = ...
            rekeyResult.messagesSent * cfg.messageSize;

    end

end
