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
    rng(randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);
    sim = Simulation(cfg, protocol);

    % Establish the initial DT prediction state.
    sim.updateDigitalTwins();

    targetCluster = 1;
    disturbanceTime = 40.0;
    leaveTime = 41.0;
    perturbation = [10 0];

    % Advance the stochastic simulation up to the disturbance time while
    % preserving the configured Poisson event model.
    while sim.currentTime < disturbanceTime
        sim.step();
    end

    % Select the affected UAVs from the population that actually exists at
    % the disturbance time. This avoids assuming that the initial members
    % survived the preceding stochastic workload.
    members = swarm.findCluster(targetCluster).getActiveUAVs();

    if numel(members) < 4
        error('DTStochasticStressTest:Population', ...
            'Target cluster must contain at least four active UAVs.');
    end

    disturbedIDs = [members(2).id, members(3).id];
    leavingID = members(4).id;

    % Apply a deterministic physical disturbance to two UAVs in the target
    % cluster so that the established DT prediction becomes stale.
    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        if ~isempty(uav)
            uav.position = uav.position + perturbation;
        end
    end

    % Observe the disturbance now. This deliberately leaves the resulting
    % high stability scores in the DT agents until the explicit leave below.
    % The next normal DT update is intentionally not performed before the
    % leave request, otherwise the one-step disturbance would be absorbed
    % into a new prediction and the score would return toward zero.
    sim.updateDigitalTwins();

    disturbedScores = zeros(1, numel(disturbedIDs));
    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        if ~isempty(uav)
            disturbedScores(i) = uav.dt.stabilityScore;
        end
    end

    % Advance physical time by one second without refreshing the DTs. This
    % preserves the observed disturbance scores until the leave decision at
    % t=41 s.
    while sim.currentTime < leaveTime
        sim.swarm.step(cfg);
        sim.currentTime = sim.currentTime + cfg.timeStep;
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
