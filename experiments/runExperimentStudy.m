function results = runExperimentStudy( ...
        protocolNames, swarmSizes, eventType, repetitions, clusterID, baseSeed)
%RUNEXPERIMENTSTUDY Run repeated controlled experiments.
%
%   RESULTS = RUNEXPERIMENTSTUDY(PROTOCOLNAMES, SWARMSIZES, EVENTTYPE,
%   REPETITIONS, CLUSTERID, BASESEED) executes the controlled experiment
%   for every protocol, swarm size, and repetition combination.
%
%   The same seed is used across protocols within each repetition so that
%   protocol comparisons are paired on the same generated swarm.
%
%   Statistical aggregation is intentionally not performed here.

    if nargin < 4
        error('runExperimentStudy:InvalidArguments', ...
            'protocolNames, swarmSizes, eventType, and repetitions are required.');
    end

    if nargin < 5
        clusterID = 1;
    end

    if nargin < 6
        baseSeed = 42;
    end

    protocolNames = string(protocolNames);
    swarmSizes = swarmSizes(:)';
    eventType = string(eventType);

    if isempty(protocolNames)
        error('runExperimentStudy:EmptyProtocols', ...
            'At least one protocol must be specified.');
    end

    if isempty(swarmSizes)
        error('runExperimentStudy:EmptySwarmSizes', ...
            'At least one swarm size must be specified.');
    end

    if repetitions < 1 || mod(repetitions,1) ~= 0
        error('runExperimentStudy:InvalidRepetitions', ...
            'repetitions must be a positive integer.');
    end

    if baseSeed < 0 || mod(baseSeed,1) ~= 0
        error('runExperimentStudy:InvalidBaseSeed', ...
            'baseSeed must be a non-negative integer.');
    end

    if eventType ~= "Join" && eventType ~= "Leave"
        error('runExperimentStudy:InvalidEventType', ...
            'eventType must be "Join" or "Leave".');
    end

    totalRuns = numel(protocolNames) * ...
        numel(swarmSizes) * repetitions;

    results = struct([]);
    index = 0;

    for r = 1:repetitions

        randomSeed = baseSeed + r - 1;

        for p = 1:numel(protocolNames)

            for s = 1:numel(swarmSizes)

                index = index + 1;

                switch eventType

                    case "Join"
                        result = runJoinExperiment( ...
                            protocolNames(p), swarmSizes(s), ...
                            clusterID, r, randomSeed);

                    case "Leave"
                        result = runLeaveExperiment( ...
                            protocolNames(p), swarmSizes(s), ...
                            clusterID, r, randomSeed);

                end

                results(index) = result.toStruct();

            end

        end

    end

end
