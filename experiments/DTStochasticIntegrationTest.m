function report = DTStochasticIntegrationTest(protocolName, swarmSize, randomSeed, numRuns)
%DTSTOCHASTICINTEGRATIONTEST Validate the full stochastic DT lifecycle.
%
% Each run initializes the DT observation, schedules one controlled physical
% disturbance through the normal event queue, advances the real Simulation
% lifecycle until the DT prediction is created, and then lets the normal
% stochastic realization mechanism schedule/execute the predicted departure.
% No production method is bypassed for prediction or realization.

    if nargin < 1
        protocolName = "DTHSBP";
    end
    if nargin < 2
        swarmSize = 1000;
    end
    if nargin < 3
        randomSeed = 42;
    end
    if nargin < 4
        numRuns = 100;
    end

    if string(protocolName) ~= "DTHSBP"
        error('DTStochasticIntegrationTest:Protocol', ...
            'This test targets DTHSBP only.');
    end

    validateattributes(numRuns, {'numeric'}, ...
        {'scalar','real','finite','integer','>=',1});

    baseCfg = config();
    baseCfg.numUAVs = swarmSize;

    if mod(baseCfg.numUAVs, baseCfg.numClusters) ~= 0
        error('DTStochasticIntegrationTest:Configuration', ...
            'swarmSize must be divisible by numClusters.');
    end

    baseCfg.clusterSize = baseCfg.numUAVs / baseCfg.numClusters;
    baseCfg.joinRate = 0;
    baseCfg.failureRate = 0;
    baseCfg.dtDisturbanceEnabled = false;
    baseCfg.dtPredictedDepartureEnabled = true;

    % Preserve the configured ordinary Leave hazard as the analytical DT
    % realization anchor. Ordinary Poisson membership events are suppressed
    % in this controlled test through a dedicated simulation flag, so the
    % Leave rate can remain nonzero for the DT hazard model.
    baseCfg.dtIntegrationSuppressMembershipEvents = true;

    totalCreated = 0;
    totalRealized = 0;
    totalUnrealized = 0;
    totalBatchRekeys = 0;
    totalLeaveEvents = 0;
    totalActiveDepartures = 0;
    scoreSamples = [];
    probabilitySamples = [];

    targetCluster = 1;
    targetMemberOffset = [2 3];
    perturbation = [baseCfg.thetaLeave + 1e-3 0];

    for runIndex = 1:numRuns
        cfg = baseCfg;
        cfg.randomSeed = randomSeed + runIndex - 1;
        rng(cfg.randomSeed);

        swarm = Swarm(cfg);
        protocol = DTHSBP(swarm);
        sim = Simulation(cfg, protocol);

        members = swarm.findCluster(targetCluster).getActiveUAVs();
        if numel(members) < max(targetMemberOffset)
            error('DTStochasticIntegrationTest:Population', ...
                'Target cluster does not contain enough UAVs.');
        end

        targetIDs = [members(targetMemberOffset(1)).id, ...
                     members(targetMemberOffset(2)).id];

        % Establish the baseline DT prediction state before the controlled
        % physical disturbance enters the normal event queue.
        sim.updateDigitalTwins();

        sim.eventQueue.schedule(DTDisturbanceEvent( ...
            sim.currentTime + cfg.timeStep, ...
            targetCluster, ...
            targetIDs, ...
            perturbation, ...
            [0 0], ...
            0));

        % t=1: execute the controlled physical disturbance.
        sim.step();

        % t=2: DT observes the disturbed state and may create predictions;
        % schedulePredictedDepartures() materializes successful realizations.
        sim.step();

        statsAfterPrediction = sim.statistics.getStatistics();
        if statsAfterPrediction.dtPredictionsCreated ~= 2
            error('DTStochasticIntegrationTest:Prediction', ...
                'Expected exactly two controlled DT predictions; got %d.', ...
                statsAfterPrediction.dtPredictionsCreated);
        end

        predictedUAV = swarm.findUAV(targetIDs(1));
        score = predictedUAV.dt.stabilityScore;
        probability = sim.computeDTDepartureProbability( ...
            score, cfg.predictionHorizon);

        scoreSamples(end+1) = score;
        probabilitySamples(end+1) = probability;

        % t=3: scheduled predicted-departure events are due and execute at
        % the beginning of the normal Simulation.step().
        sim.step();

        stats = sim.statistics.getStatistics();
        totalCreated = totalCreated + stats.dtPredictionsCreated;
        totalRealized = totalRealized + stats.dtPredictionsRealized;
        totalUnrealized = totalUnrealized + stats.dtPredictionsUnrealized;
        totalBatchRekeys = totalBatchRekeys + stats.batchRekeys;
        totalLeaveEvents = totalLeaveEvents + stats.leaveEvents;
        totalActiveDepartures = totalActiveDepartures + ...
            (swarmSize - swarm.activeUAVs());
    end

    empiricalRatio = totalRealized / max(1,totalCreated);
    analyticalProbability = mean(probabilitySamples);
    standardError = sqrt( ...
        analyticalProbability * (1 - analyticalProbability) / max(1,totalCreated));
    tolerance = 5 * standardError + 0.01;

    report = struct();
    report.protocol = string(protocolName);
    report.swarmSize = swarmSize;
    report.randomSeed = randomSeed;
    report.numRuns = numRuns;
    report.controlledScore = baseCfg.thetaLeave + 1e-3;
    report.thresholdMargin = 1e-3;
    report.totalPredictionsCreated = totalCreated;
    report.totalPredictionsRealized = totalRealized;
    report.totalPredictionsUnrealized = totalUnrealized;
    report.empiricalRealizationRatio = empiricalRatio;
    report.meanAnalyticalProbability = analyticalProbability;
    report.absoluteError = abs(empiricalRatio - analyticalProbability);
    report.standardError = standardError;
    report.acceptanceTolerance = tolerance;
    report.totalBatchRekeys = totalBatchRekeys;
    report.totalLeaveEvents = totalLeaveEvents;
    report.totalActiveDepartures = totalActiveDepartures;
    report.meanDTStabilityScore = mean(scoreSamples);
    report.predictionsPerRunInvariant = (totalCreated == 2*numRuns);
    report.accountingInvariant = ...
        (totalUnrealized == totalCreated - totalRealized);
    report.statisticalAgreement = ...
        report.absoluteError <= report.acceptanceTolerance;
    report.departureAccountingInvariant = ...
        (totalActiveDepartures == totalLeaveEvents);

    fprintf('============================================\n');
    fprintf('DT Stochastic Integration Test\n');
    fprintf('============================================\n');
    fprintf('Protocol                    : %s\n', report.protocol);
    fprintf('Runs                        : %d\n', numRuns);
    fprintf('Controlled DT score        : %.12f\n', report.controlledScore);
    fprintf('Predictions created        : %d\n', totalCreated);
    fprintf('Predictions realized       : %d\n', totalRealized);
    fprintf('Predictions unrealized     : %d\n', totalUnrealized);
    fprintf('Mean DT stability score    : %.12f\n', report.meanDTStabilityScore);
    fprintf('Mean analytical P          : %.12f\n', analyticalProbability);
    fprintf('Empirical realization ratio: %.12f\n', empiricalRatio);
    fprintf('Absolute error              : %.12f\n', report.absoluteError);
    fprintf('5-SE + 0.01 tolerance       : %.12f\n', tolerance);
    fprintf('Batch rekeys                : %d\n', totalBatchRekeys);
    fprintf('Leave events                : %d\n', totalLeaveEvents);
    fprintf('Active departures           : %d\n', totalActiveDepartures);
    fprintf('Predictions/run invariant  : %d\n', report.predictionsPerRunInvariant);
    fprintf('Prediction accounting       : %d\n', report.accountingInvariant);
    fprintf('Statistical agreement       : %d\n', report.statisticalAgreement);
    fprintf('Departure accounting        : %d\n', report.departureAccountingInvariant);
    fprintf('\n');

    if ~(report.predictionsPerRunInvariant && ...
            report.accountingInvariant && ...
            report.statisticalAgreement && ...
            report.departureAccountingInvariant)
        error('DTStochasticIntegrationTest:Failed', ...
            'Full stochastic DT integration validation failed.');
    end

    fprintf('DT stochastic integration validation: PASS\n');
    fprintf('============================================\n');
end
