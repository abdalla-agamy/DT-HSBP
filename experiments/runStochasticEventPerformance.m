function result = runStochasticEventPerformance(protocolName, swarmSize, eventType, runID, randomSeed)
%RUNSTOCHASTICEVENTPERFORMANCE Run one stochastic Join/Leave performance run.
%
% The event count is generated from the existing Poisson membership model
% over the configured simulation horizon. The same stochastic event count
% and per-event seeds are used for all protocols in a paired study.
%
% Join events use the existing controlled single-UAV Join experiment.
% Leave events use the existing controlled multi-prediction Leave experiment,
% which represents one DT-correlated batch-leave episode. The Poisson process
% determines how many such episodes occur during the stochastic horizon.
%
% This function is deliberately a performance-study wrapper. It does not
% change the protocol or DT departure hazard model.

    if nargin < 3
        error('runStochasticEventPerformance:InvalidArguments', ...
            'protocolName, swarmSize, and eventType are required.');
    end
    if nargin < 4, runID = 1; end
    if nargin < 5, randomSeed = 42; end

    swarmSize = validatePositiveInteger(swarmSize,'swarmSize');
    runID = validatePositiveInteger(runID,'runID');
    randomSeed = validateNonnegativeInteger(randomSeed,'randomSeed');
    eventType = string(eventType);

    if eventType ~= "Join" && eventType ~= "Leave"
        error('runStochasticEventPerformance:InvalidEventType', ...
            'eventType must be "Join" or "Leave".');
    end

    cfg = config();
    if ~isfield(cfg,'simulationTime') || cfg.simulationTime <= 0
        error('runStochasticEventPerformance:InvalidSimulationTime', ...
            'simulationTime must be positive.');
    end

    %% Generate the stochastic event count from the existing Poisson model.
    workloadSeed = deriveSeed(randomSeed, 700001);
    previousState = rng;
    cleanup = onCleanup(@() rng(previousState)); %#ok<NASGU>
    rng(workloadSeed);

    switch eventType
        case "Join"
            lambda = cfg.joinRate;
        case "Leave"
            lambda = cfg.leaveRate;
    end

    eventCount = poissrnd(lambda * cfg.simulationTime);

    %% Aggregate event-level observations using paired per-event seeds.
    totalLeaderTime = 0;
    totalFollowerTime = 0;
    totalAdmissionTime = 0;
    totalMessages = 0;
    totalBytes = 0;
    totalRekeys = 0;
    totalPredictedLeaves = 0;
    successfulEvents = 0;

    for eventIndex = 1:eventCount
        eventSeed = deriveSeed(randomSeed, 800000 + eventIndex);

        switch eventType
            case "Join"
                observation = runJoinExperiment( ...
                    protocolName, swarmSize, 1, eventIndex, eventSeed);
            case "Leave"
                observation = runLeaveExperiment( ...
                    protocolName, swarmSize, 1, eventIndex, eventSeed);
        end

        if ~observation.success
            continue;
        end

        successfulEvents = successfulEvents + 1;
        totalLeaderTime = totalLeaderTime + observation.leaderTime;
        totalFollowerTime = totalFollowerTime + observation.followerTime;
        totalAdmissionTime = totalAdmissionTime + observation.dtAdmissionTime;
        totalMessages = totalMessages + observation.messageCount;
        totalBytes = totalBytes + observation.messageBytes;
        totalRekeys = totalRekeys + observation.rekeyCount;

        if eventType == "Leave" && ~isempty(observation.predictedLeaves)
            totalPredictedLeaves = totalPredictedLeaves + numel(observation.predictedLeaves);
        end
    end

    result = struct();
    result.protocol = string(protocolName);
    result.eventType = eventType;
    result.runID = runID;
    result.randomSeed = randomSeed;
    result.swarmSize = swarmSize;
    result.simulationTime = cfg.simulationTime;
    result.eventRate = lambda;
    result.eventCount = eventCount;
    result.successfulEvents = successfulEvents;
    result.failedEvents = eventCount - successfulEvents;
    result.leaderTime = totalLeaderTime;
    result.followerTime = totalFollowerTime;
    result.dtAdmissionTime = totalAdmissionTime;
    result.messageCount = totalMessages;
    result.messageBytes = totalBytes;
    result.rekeyCount = totalRekeys;
    result.predictedLeaves = totalPredictedLeaves;
    result.success = (successfulEvents == eventCount);
    if result.success
        result.status = "Success";
    else
        result.status = "PartialFailure";
    end
end

function seed = deriveSeed(baseSeed, offset)
    modulus = 4294967291;
    seed = mod(double(baseSeed) + double(offset), modulus);
    seed = floor(seed);
end

function value = validatePositiveInteger(value,name)
    if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || ...
            value < 1 || mod(value,1) ~= 0
        error('runStochasticEventPerformance:InvalidArgument', ...
            '%s must be a positive integer.',name);
    end
end

function value = validateNonnegativeInteger(value,name)
    if ~isscalar(value) || ~isnumeric(value) || ~isfinite(value) || ...
            value < 0 || mod(value,1) ~= 0
        error('runStochasticEventPerformance:InvalidArgument', ...
            '%s must be a non-negative integer.',name);
    end
end
