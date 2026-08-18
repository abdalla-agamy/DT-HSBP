function report = DTPredictedDepartureLifecycleTest(protocolName, swarmSize, randomSeed)
%DTPREDICTEDDEPARTURELIFECYCLETEST Validate the full DT departure event lifecycle.
%
% This diagnostic validates the production Simulation lifecycle from a
% persistent DT prediction through event scheduling, event execution, and
% DTHSBP cluster-local batch rekeying.
%
% The test disables exogenous stochastic membership events and physical DT
% disturbances so that only the controlled DT predictions participate.

    if nargin < 1
        protocolName = "DTHSBP";
    end
    if nargin < 2
        swarmSize = 1000;
    end
    if nargin < 3
        randomSeed = 42;
    end

    if string(protocolName) ~= "DTHSBP"
        error('DTPredictedDepartureLifecycleTest:Protocol', ...
            'This lifecycle test targets DTHSBP only.');
    end

    cfg = config();
    cfg.numUAVs = swarmSize;

    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('DTPredictedDepartureLifecycleTest:Configuration', ...
            'swarmSize must be divisible by numClusters.');
    end

    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = randomSeed;

    % Isolate the DT predicted-departure lifecycle from exogenous events.
    cfg.joinRate = 0;
    cfg.leaveRate = 0;
    cfg.failureRate = 0;
    cfg.dtDisturbanceEnabled = false;
    cfg.dtPredictedDepartureEnabled = true;
    cfg.dtPredictedDepartureProbability = 1.0;

    rng(randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);
    sim = Simulation(cfg, protocol);

    targetCluster = 1;
    members = swarm.findCluster(targetCluster).getActiveUAVs();

    if numel(members) < 4
        error('DTPredictedDepartureLifecycleTest:Population', ...
            'Target cluster must contain at least four active UAVs.');
    end

    predictedIDs = [members(2).id, members(3).id];

    % Establish the baseline DT observation at t=0.
    sim.updateDigitalTwins();

    % Apply a controlled physical disturbance before the normal Simulation
    % step. At t=1 the DT update compares the disturbed state with the
    % stored prediction and creates persistent predictions for both UAVs.
    perturbation = [10 0];
    for i = 1:numel(predictedIDs)
        uav = swarm.findUAV(predictedIDs(i));
        uav.position = uav.position + perturbation;
    end

    initialActive = swarm.activeUAVs();

    % Normal Simulation.step() creates the predictions and schedules the
    % corresponding DTPredictedDepartureEvent objects for t=2.
    sim.step();

    predictionTime = sim.currentTime;
    predictionsCreated = false(1,numel(predictedIDs));
    for i = 1:numel(predictedIDs)
        uav = swarm.findUAV(predictedIDs(i));
        if ~isempty(uav)
            predictionsCreated(i) = uav.dt.hasPredictedLeave(predictionTime);
        end
    end

    queuedEvents = sim.eventQueue.count();
    scheduledDepartureTime = predictionTime + cfg.predictionHorizon;

    % Simulation.step() executes due events at its beginning. The first
    % step below advances from t=1 to t=2, establishing the exact execution
    % boundary without executing the t=2 events yet.
    sim.step();
    executionTime = sim.currentTime;

    if executionTime ~= scheduledDepartureTime
        error('DTPredictedDepartureLifecycleTest:Timing', ...
            'Simulation did not reach the scheduled departure time.');
    end

    % The next step starts at t=2, so the two due predicted-departure events
    % are executed before the physical/DT update. Capture the state after
    % that execution step.
    sim.step();

    activeAfterExecution = swarm.activeUAVs();
    statsAfterExecution = sim.statistics.getStatistics();
    queuedAfterExecution = sim.eventQueue.count();

    report = struct();
    report.protocol = string(protocolName);
    report.swarmSize = swarmSize;
    report.randomSeed = randomSeed;
    report.targetCluster = targetCluster;
    report.predictedUAVs = predictedIDs;
    report.perturbation = perturbation;
    report.predictionTime = predictionTime;
    report.scheduledDepartureTime = scheduledDepartureTime;
    report.executionTime = executionTime;
    report.initialActiveUAVs = initialActive;
    report.predictionsCreated = predictionsCreated;
    report.queuedPredictedDepartureEvents = queuedEvents;
    report.activeUAVsAfterExecution = activeAfterExecution;
    report.queuedEventsAfterExecution = queuedAfterExecution;
    report.predictedLeaves = statsAfterExecution.predictedLeaves;
    report.batchRekeys = statsAfterExecution.batchRekeys;
    report.localRekeys = statsAfterExecution.localRekeys;
    report.leaveEvents = statsAfterExecution.leaveEvents;
    report.totalMessages = statsAfterExecution.totalMessages;

    report.predictionsCreatedCorrectly = all(predictionsCreated);
    report.twoDepartureEventsScheduled = (queuedEvents == numel(predictedIDs));
    report.departureReachedExpectedTime = ...
        (executionTime == scheduledDepartureTime);
    report.twoUAVsDeparted = ...
        (activeAfterExecution == initialActive - numel(predictedIDs));
    report.singleBatchRekey = (statsAfterExecution.batchRekeys == 1);
    report.oneCollateralPredictionConsumed = ...
        (statsAfterExecution.predictedLeaves == numel(predictedIDs) - 1);
    report.noPendingDepartureEvents = (queuedAfterExecution == 0);
    report.noLocalRekey = (statsAfterExecution.localRekeys == 0);

    fprintf('============================================\n');
    fprintf('DT Predicted Departure Lifecycle Test\n');
    fprintf('============================================\n');
    fprintf('Protocol                       : %s\n', report.protocol);
    fprintf('Initial active UAVs            : %d\n', initialActive);
    fprintf('Predicted UAVs                 : %s\n', mat2str(predictedIDs));
    fprintf('Prediction creation time      : %.1f s\n', predictionTime);
    fprintf('Scheduled departure time      : %.1f s\n', scheduledDepartureTime);
    fprintf('Execution time                : %.1f s\n', executionTime);
    fprintf('Predictions created           : %s\n', mat2str(predictionsCreated));
    fprintf('Departure events scheduled    : %d\n', queuedEvents);
    fprintf('Active UAVs after execution   : %d\n', activeAfterExecution);
    fprintf('Predicted leaves consumed     : %d\n', statsAfterExecution.predictedLeaves);
    fprintf('Batch rekeys                  : %d\n', statsAfterExecution.batchRekeys);
    fprintf('Local rekeys                  : %d\n', statsAfterExecution.localRekeys);
    fprintf('Leave events                  : %d\n', statsAfterExecution.leaveEvents);
    fprintf('Pending events after execute  : %d\n', queuedAfterExecution);
    fprintf('Messages                      : %d\n', statsAfterExecution.totalMessages);
    fprintf('\n');

    if ~(report.predictionsCreatedCorrectly && ...
            report.twoDepartureEventsScheduled && ...
            report.departureReachedExpectedTime && ...
            report.twoUAVsDeparted && ...
            report.singleBatchRekey && ...
            report.oneCollateralPredictionConsumed && ...
            report.noPendingDepartureEvents && ...
            report.noLocalRekey)
        error('DTPredictedDepartureLifecycleTest:Failed', ...
            'DT predicted departure lifecycle validation failed.');
    end

    fprintf('DT predicted departure lifecycle validation: PASS\n');
    fprintf('============================================\n');
end
