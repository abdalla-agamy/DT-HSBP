function result = runStochasticExperiment(protocolName, swarmSize, runID, randomSeed)
%RUNSTOCHASTICEXPERIMENT Run one Poisson-driven stochastic simulation.

    if nargin < 2
        error('runStochasticExperiment:InvalidArguments', ...
            'protocolName and swarmSize are required.');
    end
    if nargin < 3
        runID = 1;
    end
    if nargin < 4
        randomSeed = 42;
    end

    swarmSize = validatePositiveInteger(swarmSize, 'swarmSize');
    runID = validatePositiveInteger(runID, 'runID');
    randomSeed = validateNonnegativeInteger(randomSeed, 'randomSeed');

    cfg = config();
    cfg.numUAVs = swarmSize;

    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('runStochasticExperiment:InvalidConfiguration', ...
            'swarmSize must be divisible by the number of clusters.');
    end

    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = randomSeed;
    rng(randomSeed);

    swarm = Swarm(cfg);

    switch string(protocolName)
        case "FlatSBP"
            protocol = FlatSBP(swarm);
        case "HSBP"
            protocol = HSBP(swarm);
        case "DTHSBP"
            protocol = DTHSBP(swarm);
        otherwise
            error('runStochasticExperiment:UnknownProtocol', ...
                'Unknown protocol: %s', string(protocolName));
    end

    sim = Simulation(cfg, protocol);
    sim.run();

    stats = sim.statistics.getStatistics();

    result = struct();
    result.protocol = string(protocolName);
    result.eventType = "Stochastic";
    result.runID = runID;
    result.randomSeed = randomSeed;
    result.initialSwarmSize = swarmSize;
    result.finalActiveUAVs = swarm.activeUAVs();
    result.simulationTime = cfg.simulationTime;
    result.timeStep = cfg.timeStep;

    result.joinRate = cfg.joinRate;
    result.leaveRate = cfg.leaveRate;
    result.failureRate = cfg.failureRate;
    result.dtDisturbanceEnabled = cfg.dtDisturbanceEnabled;
    result.dtDisturbanceRate = cfg.dtDisturbanceRate;
    result.generatedJoinEvents = sim.generatedJoinEvents;
    result.generatedLeaveEvents = sim.generatedLeaveEvents;
    result.generatedFailureEvents = sim.generatedFailureEvents;
    result.dtDisturbanceCount = sim.dtDisturbanceCount;

    result.dtDepartureHazardModel = cfg.dtDepartureHazardModel;
    result.dtPredictionsCreated = stats.dtPredictionsCreated;
    result.dtPredictionsRealized = stats.dtPredictionsRealized;
    result.dtPredictionsUnrealized = stats.dtPredictionsUnrealized;
    result.dtRealizationRatio = stats.dtRealizationRatio;

    result.joinEvents = stats.joinEvents;
    result.leaveEvents = stats.leaveEvents;
    result.failureEvents = stats.failureEvents;
    result.rejectedJoins = stats.rejectedJoins;

    result.predictedLeaves = stats.predictedLeaves;
    result.localRekeys = stats.localRekeys;
    result.batchRekeys = stats.batchRekeys;

    result.totalMessages = stats.totalMessages;
    result.totalBytes = stats.totalBytes;
    result.communicationCost = stats.communicationCost;

    result.totalEncryptions = stats.totalEncryptions;
    result.totalKeysGenerated = stats.totalKeysGenerated;
    result.totalDecryptions = stats.totalDecryptions;
    result.totalHashOperations = stats.totalHashOperations;
    result.totalRandomNumbers = stats.totalRandomNumbers;

    result.success = true;
    result.status = "Success";

end

function value = validatePositiveInteger(value, name)
    if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || ...
            value < 1 || mod(value, 1) ~= 0
        error('runStochasticExperiment:InvalidArgument', ...
            '%s must be a positive integer.', name);
    end
end

function value = validateNonnegativeInteger(value, name)
    if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || ...
            value < 0 || mod(value, 1) ~= 0
        error('runStochasticExperiment:InvalidArgument', ...
            '%s must be a non-negative integer.', name);
    end
end
