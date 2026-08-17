function report = DTStochasticStabilityDiagnostic(protocolName, swarmSize, randomSeed)
%DTSTOCHASTICSTABILITYDIAGNOSTIC Compare DT stability before/after disturbance.
%
% Diagnostic only. Does not perform a Leave and does not modify protocol,
% DT, threshold, or physical-model parameters. It measures how many UAVs in
% the target cluster exceed thetaLeave immediately before and after the
% controlled disturbance used by DTStochasticStressTest.

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
        error('DTStochasticStabilityDiagnostic:Protocol', ...
            'This diagnostic targets DTHSBP only.');
    end

    cfg = config();
    cfg.numUAVs = swarmSize;

    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('DTStochasticStabilityDiagnostic:Configuration', ...
            'swarmSize must be divisible by numClusters.');
    end

    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = randomSeed;
    rng(randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);
    sim = Simulation(cfg, protocol);
    sim.updateDigitalTwins();

    targetCluster = 1;
    members = swarm.findCluster(targetCluster).getActiveUAVs();
    if numel(members) < 4
        error('DTStochasticStabilityDiagnostic:Population', ...
            'Target cluster must contain at least four active UAVs.');
    end

    disturbedIDs = [members(2).id, members(3).id];
    disturbanceTime = 40.0;
    perturbation = [10 0];

    while sim.currentTime < disturbanceTime
        sim.step();
    end

    % Capture the DT state before applying the disturbance. Do not perform
    % another DT update between this capture and the disturbance update.
    beforeMembers = swarm.findCluster(targetCluster).getActiveUAVs();
    beforeScores = zeros(1, numel(beforeMembers));
    beforeIDs = zeros(1, numel(beforeMembers));
    for i = 1:numel(beforeMembers)
        beforeIDs(i) = beforeMembers(i).id;
        beforeScores(i) = beforeMembers(i).dt.stabilityScore;
    end

    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        if ~isempty(uav)
            uav.position = uav.position + perturbation;
        end
    end

    sim.updateDigitalTwins();

    afterMembers = swarm.findCluster(targetCluster).getActiveUAVs();
    afterScores = zeros(1, numel(afterMembers));
    afterIDs = zeros(1, numel(afterMembers));
    for i = 1:numel(afterMembers)
        afterIDs(i) = afterMembers(i).id;
        afterScores(i) = afterMembers(i).dt.stabilityScore;
    end

    threshold = cfg.thetaLeave;
    beforeAbove = beforeScores > threshold;
    afterAbove = afterScores > threshold;

    report = struct();
    report.protocol = string(protocolName);
    report.swarmSize = swarmSize;
    report.randomSeed = randomSeed;
    report.targetCluster = targetCluster;
    report.disturbedUAVs = disturbedIDs;
    report.perturbation = perturbation;
    report.disturbanceTime = disturbanceTime;
    report.threshold = threshold;
    report.beforeIDs = beforeIDs;
    report.beforeScores = beforeScores;
    report.afterIDs = afterIDs;
    report.afterScores = afterScores;
    report.beforeCount = numel(beforeScores);
    report.afterCount = numel(afterScores);
    report.beforeAboveCount = nnz(beforeAbove);
    report.afterAboveCount = nnz(afterAbove);
    report.beforeMin = min(beforeScores);
    report.beforeMedian = median(beforeScores);
    report.beforeMean = mean(beforeScores);
    report.beforeMax = max(beforeScores);
    report.afterMin = min(afterScores);
    report.afterMedian = median(afterScores);
    report.afterMean = mean(afterScores);
    report.afterMax = max(afterScores);
    report.newlyAboveIDs = afterIDs(afterAbove & ~beforeAbove);

    fprintf('============================================\n');
    fprintf('DT Stochastic Stability Diagnostic\n');
    fprintf('============================================\n');
    fprintf('Protocol             : %s\n', report.protocol);
    fprintf('Initial UAVs         : %d\n', swarmSize);
    fprintf('Target cluster       : %d\n', targetCluster);
    fprintf('Disturbed UAVs       : %s\n', mat2str(disturbedIDs));
    fprintf('Disturbance time     : %.1f s\n', disturbanceTime);
    fprintf('Perturbation         : %s\n', mat2str(perturbation));
    fprintf('Leave threshold      : %.6f\n', threshold);
    fprintf('\n');
    fprintf('--- BEFORE DISTURBANCE ---\n');
    fprintf('Members              : %d\n', report.beforeCount);
    fprintf('Above threshold      : %d\n', report.beforeAboveCount);
    fprintf('Min / Median / Mean  : %.6f / %.6f / %.6f\n', ...
        report.beforeMin, report.beforeMedian, report.beforeMean);
    fprintf('Max                  : %.6f\n', report.beforeMax);
    fprintf('\n');
    fprintf('--- AFTER DISTURBANCE ---\n');
    fprintf('Members              : %d\n', report.afterCount);
    fprintf('Above threshold      : %d\n', report.afterAboveCount);
    fprintf('Min / Median / Mean  : %.6f / %.6f / %.6f\n', ...
        report.afterMin, report.afterMedian, report.afterMean);
    fprintf('Max                  : %.6f\n', report.afterMax);
    fprintf('Newly above threshold: %d\n', numel(report.newlyAboveIDs));
    fprintf('\n');

    if ~isempty(report.newlyAboveIDs)
        fprintf('First newly unstable IDs: %s\n', ...
            mat2str(report.newlyAboveIDs(1:min(10,end))));
    end

    fprintf('============================================\n');
end
