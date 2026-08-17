function StochasticExperimentTest()
%STOCHASTICEXPERIMENTTEST Validate one Poisson-driven simulation run.
%
% The test uses the configured stochastic event rates and a small swarm so
% that the full Simulation lifecycle is exercised without a large runtime.

    fprintf('============================================\n');
    fprintf('Stochastic Experiment Test\n');
    fprintf('============================================\n');

    swarmSize = 1000;
    runID = 1;
    randomSeed = 42;

    result = runStochasticExperiment( ...
        "DTHSBP", swarmSize, runID, randomSeed);

    fprintf('Protocol             : %s\n', result.protocol);
    fprintf('Initial UAVs         : %d\n', result.initialSwarmSize);
    fprintf('Final active UAVs    : %d\n', result.finalActiveUAVs);
    fprintf('Simulation time      : %.1f s\n', result.simulationTime);
    fprintf('Time step            : %.1f s\n', result.timeStep);
    fprintf('Join rate            : %.3f /s\n', result.joinRate);
    fprintf('Leave rate           : %.3f /s\n', result.leaveRate);
    fprintf('Failure rate         : %.3f /s\n', result.failureRate);
    fprintf('Join events          : %d\n', result.joinEvents);
    fprintf('Leave events         : %d\n', result.leaveEvents);
    fprintf('Failure events       : %d\n', result.failureEvents);
    fprintf('Rejected joins       : %d\n', result.rejectedJoins);
    fprintf('Predicted leaves     : %d\n', result.predictedLeaves);
    fprintf('Local rekeys         : %d\n', result.localRekeys);
    fprintf('Batch rekeys         : %d\n', result.batchRekeys);
    fprintf('Messages             : %d\n', result.totalMessages);
    fprintf('Bytes                : %d\n', result.totalBytes);

    assert(result.success, ...
        'StochasticExperimentTest:RunFailed', ...
        'The stochastic experiment did not complete successfully.');

    assert(result.simulationTime > 0, ...
        'StochasticExperimentTest:InvalidSimulationTime', ...
        'Simulation time must be positive.');

    assert(result.timeStep > 0, ...
        'StochasticExperimentTest:InvalidTimeStep', ...
        'Time step must be positive.');

    assert(result.joinRate >= 0 && result.leaveRate >= 0 && ...
        result.failureRate >= 0, ...
        'StochasticExperimentTest:InvalidRates', ...
        'Configured event rates must be non-negative.');

    assert(result.finalActiveUAVs >= 0, ...
        'StochasticExperimentTest:InvalidMembership', ...
        'Final active membership cannot be negative.');

    assert(result.joinEvents >= 0 && result.leaveEvents >= 0 && ...
        result.failureEvents >= 0, ...
        'StochasticExperimentTest:InvalidEventCounts', ...
        'Stochastic event counts must be non-negative.');

    fprintf('\nStochastic experiment validation: PASS\n');
    fprintf('============================================\n');
end
