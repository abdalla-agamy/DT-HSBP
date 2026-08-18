function report = DTRealizationStatisticsTest(protocolName, swarmSize, randomSeed, numRuns)
%DTREALIZATIONSTATISTICSTEST Validate empirical DT realization statistics.
%
% Run multiple controlled one-second DT prediction experiments with no
% exogenous membership or disturbance events. The physical disturbance is
% applied directly to the same two UAVs in each run, producing two DT
% predictions just above the leave threshold. The model then samples the
% stochastic realization probability through Simulation.schedulePredictedDepartures().
%
% The empirical realization ratio is compared with the analytical
% probability for the controlled DT score. This is a statistical
% diagnostic, not a production benchmark.

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
        numRuns = 1000;
    end

    if string(protocolName) ~= "DTHSBP"
        error('DTRealizationStatisticsTest:Protocol', ...
            'This test targets DTHSBP only.');
    end

    validateattributes(numRuns, {'numeric'}, ...
        {'scalar','real','finite','integer','>=',1});

    baseCfg = config();
    baseCfg.numUAVs = swarmSize;

    if mod(baseCfg.numUAVs, baseCfg.numClusters) ~= 0
        error('DTRealizationStatisticsTest:Configuration', ...
            'swarmSize must be divisible by numClusters.');
    end

    baseCfg.clusterSize = baseCfg.numUAVs / baseCfg.numClusters;
    baseCfg.joinRate = 0;
    baseCfg.failureRate = 0;
    baseCfg.dtDisturbanceEnabled = false;
    baseCfg.dtPredictedDepartureEnabled = true;

    % StabilityModel.shouldLeave() uses a strict inequality (D > thetaLeave).
    % Therefore the controlled residual must be slightly above the threshold
    % rather than exactly equal to it. The analytical probability is computed
    % for that same controlled score.
    targetCluster = 1;
    thresholdMargin = 1e-3;
    controlledScore = baseCfg.thetaLeave + thresholdMargin;
    perturbation = [controlledScore 0];

    analyticalProbability = 1 - exp( ...
        -(baseCfg.leaveRate * ...
          exp(controlledScore / baseCfg.thetaLeave - 1)) * ...
          baseCfg.predictionHorizon);

    totalCreated = 0;
    totalRealized = 0;
    totalUnrealized = 0;
    totalBatchRekeys = 0;

    for runIndex = 1:numRuns
        cfg = baseCfg;
        cfg.randomSeed = randomSeed + runIndex - 1;
        rng(cfg.randomSeed);

        swarm = Swarm(cfg);
        protocol = DTHSBP(swarm);
        sim = Simulation(cfg, protocol);

        members = swarm.findCluster(targetCluster).getActiveUAVs();
        if numel(members) < 3
            error('DTRealizationStatisticsTest:Population', ...
                'Target cluster must contain at least three active UAVs.');
        end

        predictedIDs = [members(2).id, members(3).id];

        sim.updateDigitalTwins();

        for i = 1:numel(predictedIDs)
            uav = swarm.findUAV(predictedIDs(i));
            uav.position = uav.position + perturbation;
        end

        sim.step();

        stats = sim.statistics.getStatistics();
        created = stats.dtPredictionsCreated;
        realized = stats.dtPredictionsRealized;

        totalCreated = totalCreated + created;
        totalRealized = totalRealized + realized;
        totalUnrealized = totalUnrealized + stats.dtPredictionsUnrealized;
        totalBatchRekeys = totalBatchRekeys + stats.batchRekeys;
    end

    if totalCreated > 0
        empiricalRatio = totalRealized / totalCreated;
    else
        empiricalRatio = NaN;
    end

    % With two controlled predictions per run, use a conservative absolute
    % tolerance of five standard deviations around the analytical probability.
    trialCount = totalCreated;
    standardError = sqrt( ...
        analyticalProbability * (1 - analyticalProbability) / max(1, trialCount));
    tolerance = 5 * standardError + 0.01;

    report = struct();
    report.protocol = string(protocolName);
    report.swarmSize = swarmSize;
    report.randomSeed = randomSeed;
    report.numRuns = numRuns;
    report.predictionHorizon = baseCfg.predictionHorizon;
    report.leaveRate = baseCfg.leaveRate;
    report.thetaLeave = baseCfg.thetaLeave;
    report.controlledScore = controlledScore;
    report.thresholdMargin = thresholdMargin;
    report.analyticalProbability = analyticalProbability;
    report.totalPredictionsCreated = totalCreated;
    report.totalPredictionsRealized = totalRealized;
    report.totalPredictionsUnrealized = totalUnrealized;
    report.empiricalRealizationRatio = empiricalRatio;
    report.absoluteError = abs(empiricalRatio - analyticalProbability);
    report.standardError = standardError;
    report.acceptanceTolerance = tolerance;
    report.totalBatchRekeys = totalBatchRekeys;
    report.allRunsProducedControlledPredictions = (totalCreated == 2*numRuns);
    report.statisticalAgreement = ...
        report.absoluteError <= report.acceptanceTolerance;

    fprintf('============================================\n');
    fprintf('DT Realization Statistics Test\n');
    fprintf('============================================\n');
    fprintf('Protocol                    : %s\n', report.protocol);
    fprintf('Runs                        : %d\n', numRuns);
    fprintf('Controlled DT score        : %.6f\n', controlledScore);
    fprintf('Predictions created        : %d\n', totalCreated);
    fprintf('Predictions realized       : %d\n', totalRealized);
    fprintf('Predictions unrealized     : %d\n', totalUnrealized);
    fprintf('Analytical P                : %.12f\n', analyticalProbability);
    fprintf('Empirical realization ratio: %.12f\n', empiricalRatio);
    fprintf('Absolute error              : %.12f\n', report.absoluteError);
    fprintf('5-SE + 0.01 tolerance       : %.12f\n', tolerance);
    fprintf('Batch rekeys                : %d\n', totalBatchRekeys);
    fprintf('Controlled predictions      : %d\n', report.allRunsProducedControlledPredictions);
    fprintf('Statistical agreement       : %d\n', report.statisticalAgreement);
    fprintf('\n');

    if ~(report.allRunsProducedControlledPredictions && ...
            report.statisticalAgreement)
        error('DTRealizationStatisticsTest:Failed', ...
            'Empirical DT realization statistics failed validation.');
    end

    fprintf('DT realization statistics validation: PASS\n');
    fprintf('============================================\n');
end
