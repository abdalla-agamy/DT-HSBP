function report = DTStochasticStressTest(protocolName, swarmSize, randomSeed)
%DTSTOCHASTICSTRESSTEST Validate DT-driven predicted leaves inside Simulation.
%
% This is a mechanism-validation experiment, not part of the normal
% Poisson stochastic benchmark. It starts a stochastic simulation,
% introduces a deterministic physical disturbance at a chosen time, then
% verifies that DT instability can propagate into a predicted batch leave
% and one cluster rekey.
%
% The normal Poisson rates from config.m remain unchanged.

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
        error('DTStochasticStressTest:Protocol', ...
            'This stress test targets DTHSBP only.');
    end

    cfg = config();
    cfg.numUAVs = swarmSize;

    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('DTStochasticStressTest:Configuration', ...
            'swarmSize must be divisible by numClusters.');
    end

    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = randomSeed;

    % This test validates deterministic DT prediction consumption and
    % cluster-local batch leave behavior. Automatic stochastic materializa-
    % tion of DT predictions must be disabled so unrelated predictions
    % created during the warm-up cannot contaminate the controlled result.
    cfg.dtPredictedDepartureEnabled = false;

    rng(randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);
    sim = Simulation(cfg, protocol);

    % Establish the initial DT observation/prediction state at t=0.
    sim.updateDigitalTwins();

    targetCluster = 1;
    disturbanceTime = 40.0;
    leaveTime = 41.0;
    perturbation = [10 0];

    % Advance the stochastic simulation to the disturbance instant.
    while sim.currentTime < disturbanceTime
        sim.step();
    end

    members = swarm.findCluster(targetCluster).getActiveUAVs();

    if numel(members) < 4
        error('DTStochasticStressTest:Population', ...
            'Target cluster must contain at least four active UAVs.');
    end

    disturbedIDs = [members(2).id, members(3).id];
    leavingID = members(4).id;

    % The DT prediction established at t=40 is a prediction for t=41.
    % Apply the disturbance after that prediction has been established.
    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        if ~isempty(uav)
            uav.position = uav.position + perturbation;
        end
    end

    % Advance the physical swarm to t=41 before evaluating the DT residual.
    % This keeps actual and predicted states at the same time index. Calling
    % updateDigitalTwins() immediately at t=40 would compare the t=40 actual
    % state against the already stored t=41 prediction and create a spurious
    % one-step velocity residual for every UAV.
    sim.swarm.step(cfg);
    sim.currentTime = sim.currentTime + cfg.timeStep;

    % Now the stored prediction is for t=41 and the actual state is t=41.
    % Only the intentionally disturbed UAVs should acquire the large
    % position residual.
    sim.updateDigitalTwins();

    disturbedScores = zeros(1, numel(disturbedIDs));
    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        if ~isempty(uav)
            disturbedScores(i) = uav.dt.stabilityScore;
        end
    end

    sim.processLeaveRequest(leavingID);

    stats = sim.statistics.getStatistics();

    report = struct();
    report.protocol = string(protocolName);
    report.swarmSize = swarmSize;
    report.randomSeed = randomSeed;
    report.targetCluster = targetCluster;
    report.disturbedUAVs = disturbedIDs;
    report.leavingUAV = leavingID;
    report.perturbation = perturbation;
    report.disturbanceTime = disturbanceTime;
    report.leaveTime = leaveTime;
    report.leaveThreshold = cfg.thetaLeave;
    report.disturbedStabilityScores = disturbedScores;
    report.predictedLeaves = stats.predictedLeaves;
    report.batchRekeys = stats.batchRekeys;
    report.localRekeys = stats.localRekeys;
    report.totalMessages = stats.totalMessages;
    report.totalBytes = stats.totalBytes;
    report.finalActiveUAVs = swarm.activeUAVs();

    report.thresholdCrossed = all(disturbedScores > cfg.thetaLeave);
    report.singleBatchRekey = (stats.batchRekeys == 1);
    report.predictionValidated = (stats.predictedLeaves >= numel(disturbedIDs));

    fprintf('============================================\n');
    fprintf('DT Stochastic Stress Test\n');
    fprintf('============================================\n');
    fprintf('Protocol             : %s\n', report.protocol);
    fprintf('Initial UAVs         : %d\n', swarmSize);
    fprintf('Target cluster       : %d\n', targetCluster);
    fprintf('Disturbed UAVs       : %s\n', mat2str(disturbedIDs));
    fprintf('Leaving UAV          : %d\n', leavingID);
    fprintf('Disturbance time     : %.1f s\n', disturbanceTime);
    fprintf('Leave time           : %.1f s\n', leaveTime);
    fprintf('Perturbation         : %s\n', mat2str(perturbation));
    fprintf('Stability scores     : %s\n', mat2str(disturbedScores));
    fprintf('Leave threshold      : %.6f\n', cfg.thetaLeave);
    fprintf('Threshold crossed    : %d\n', report.thresholdCrossed);
    fprintf('Predicted leaves     : %d\n', stats.predictedLeaves);
    fprintf('Batch rekeys         : %d\n', stats.batchRekeys);
    fprintf('Messages             : %d\n', stats.totalMessages);
    fprintf('Final active UAVs    : %d\n', report.finalActiveUAVs);
    fprintf('\n');

    if ~(report.thresholdCrossed && report.singleBatchRekey && report.predictionValidated)
        error('DTStochasticStressTest:Failed', ...
            'DT stochastic stress validation failed.');
    end

    fprintf('DT stochastic stress validation: PASS\n');
    fprintf('============================================\n');
end
