function report = DTDepartureHazardModelTest(protocolName, swarmSize, randomSeed)
%DTDEPARTUREHAZARDMODELTEST Validate the DT stochastic realization model.
%
% The realization model is
%   lambda_DT(S) = lambda_L * exp(S/thetaLeave - 1)
%   P(S) = 1 - exp(-lambda_DT(S) * predictionHorizon)
%
% Thus the conditional DT realization probability equals the ordinary
% one-horizon Leave probability at the DT leave threshold, increases with
% instability, and remains bounded in [0,1].

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
        error('DTDepartureHazardModelTest:Protocol', ...
            'This test targets DTHSBP only.');
    end

    cfg = config();
    cfg.numUAVs = swarmSize;

    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('DTDepartureHazardModelTest:Configuration', ...
            'swarmSize must be divisible by numClusters.');
    end

    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = randomSeed;
    cfg.joinRate = 0;
    cfg.failureRate = 0;
    cfg.dtDisturbanceEnabled = false;
    cfg.dtPredictedDepartureEnabled = true;

    rng(randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);
    sim = Simulation(cfg, protocol);

    horizon = cfg.predictionHorizon;
    threshold = cfg.thetaLeave;
    leaveRate = cfg.leaveRate;

    belowScore = threshold / 2;
    thresholdScore = threshold;
    aboveScore = threshold * 2;

    pBelow = sim.computeDTDepartureProbability(belowScore, horizon);
    pThreshold = sim.computeDTDepartureProbability(thresholdScore, horizon);
    pAbove = sim.computeDTDepartureProbability(aboveScore, horizon);

    expectedThreshold = 1 - exp(-leaveRate * horizon);

    % At the leave threshold, the DT hazard is exactly the ordinary
    % Leave Poisson hazard, by construction.
    thresholdAnchor = abs(pThreshold - expectedThreshold) < 1e-12;

    % Increasing instability must increase realization probability.
    monotonic = (pBelow < pThreshold) && (pThreshold < pAbove);

    % The probability must always be a valid probability.
    bounded = all([pBelow pThreshold pAbove] >= 0) && ...
              all([pBelow pThreshold pAbove] <= 1);

    % The configured Leave rate is the sole hazard anchor; with zero Leave
    % rate the DT realization probability must also be zero.
    zeroRateCfg = cfg;
    zeroRateCfg.leaveRate = 0;
    zeroSwarm = Swarm(zeroRateCfg);
    zeroProtocol = DTHSBP(zeroSwarm);
    zeroSim = Simulation(zeroRateCfg, zeroProtocol);
    pZeroRate = zeroSim.computeDTDepartureProbability(aboveScore, horizon);
    zeroRateInvariant = (pZeroRate == 0);

    report = struct();
    report.protocol = string(protocolName);
    report.swarmSize = swarmSize;
    report.randomSeed = randomSeed;
    report.leaveRate = leaveRate;
    report.thetaLeave = threshold;
    report.predictionHorizon = horizon;
    report.belowThresholdScore = belowScore;
    report.thresholdScore = thresholdScore;
    report.aboveThresholdScore = aboveScore;
    report.probabilityBelowThreshold = pBelow;
    report.probabilityAtThreshold = pThreshold;
    report.probabilityAboveThreshold = pAbove;
    report.expectedThresholdProbability = expectedThreshold;
    report.thresholdAnchor = thresholdAnchor;
    report.monotonicInstabilityResponse = monotonic;
    report.probabilityBounded = bounded;
    report.zeroRateProbability = pZeroRate;
    report.zeroRateInvariant = zeroRateInvariant;

    fprintf('============================================\n');
    fprintf('DT Departure Hazard Model Test\n');
    fprintf('============================================\n');
    fprintf('Protocol                    : %s\n', report.protocol);
    fprintf('Leave rate                  : %.6f /s\n', leaveRate);
    fprintf('Leave threshold             : %.6f\n', threshold);
    fprintf('Prediction horizon          : %.6f s\n', horizon);
    fprintf('P(S < threshold)            : %.12f\n', pBelow);
    fprintf('P(S = threshold)            : %.12f\n', pThreshold);
    fprintf('Expected threshold P        : %.12f\n', expectedThreshold);
    fprintf('P(S > threshold)            : %.12f\n', pAbove);
    fprintf('Zero-rate probability       : %.12f\n', pZeroRate);
    fprintf('Threshold anchor            : %d\n', thresholdAnchor);
    fprintf('Monotonic response          : %d\n', monotonic);
    fprintf('Probability bounded         : %d\n', bounded);
    fprintf('Zero-rate invariant         : %d\n', zeroRateInvariant);
    fprintf('\n');

    if ~(thresholdAnchor && monotonic && bounded && zeroRateInvariant)
        error('DTDepartureHazardModelTest:Failed', ...
            'DT departure hazard model validation failed.');
    end

    fprintf('DT departure hazard model validation: PASS\n');
    fprintf('============================================\n');
end
