function results = runExperimentSweep( ...
        protocolNames, swarmSizes, eventType, clusterID)
%RUNEXPERIMENTSWEEP Run controlled experiments over protocols and sizes.
%
%   RESULTS = RUNEXPERIMENTSWEEP(PROTOCOLNAMES, SWARMSIZES, EVENTTYPE,
%   CLUSTERID) executes one controlled experiment for every protocol and
%   swarm size combination.
%
%   EVENTTYPE must be "Join" or "Leave".
%
%   The function returns a struct array. Statistical aggregation is not
%   performed here.

    if nargin < 3
        error('runExperimentSweep:InvalidArguments', ...
            'protocolNames, swarmSizes, and eventType are required.');
    end

    if nargin < 4
        clusterID = 1;
    end

    protocolNames = string(protocolNames);
    swarmSizes = swarmSizes(:)';
    eventType = string(eventType);

    if isempty(protocolNames)
        error('runExperimentSweep:EmptyProtocols', ...
            'At least one protocol must be specified.');
    end

    if isempty(swarmSizes)
        error('runExperimentSweep:EmptySwarmSizes', ...
            'At least one swarm size must be specified.');
    end

    if any(swarmSizes < 1 | mod(swarmSizes,1) ~= 0)
        error('runExperimentSweep:InvalidSwarmSizes', ...
            'All swarm sizes must be positive integers.');
    end

    if eventType ~= "Join" && eventType ~= "Leave"
        error('runExperimentSweep:InvalidEventType', ...
            'eventType must be "Join" or "Leave".');
    end

    totalRuns = numel(protocolNames) * numel(swarmSizes);

    results = struct([]);
    index = 0;

    for p = 1:numel(protocolNames)

        for s = 1:numel(swarmSizes)

            index = index + 1;

            switch eventType

                case "Join"
                    result = runJoinExperiment( ...
                        protocolNames(p), ...
                        swarmSizes(s), ...
                        clusterID);

                case "Leave"
                    result = runLeaveExperiment( ...
                        protocolNames(p), ...
                        swarmSizes(s), ...
                        clusterID);

            end

            results(index) = result.toStruct();

        end

    end

end
