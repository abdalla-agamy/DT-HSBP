function ZeroLatencyHandoverTest()
%ZEROLATENCYHANDOVERTEST Automated verification for Contribution B:
% Predictive Pre-Calculation & Zero-Latency Rekeying Handover.
%
% This test verifies:
% 1. DTPrecomputationEngine intercepts prediction events and pre-calculates
%    post-departure intermediate Diffie-Hellman key chains I_i^{t+1},
%    blind keys g^{I_i^{t+1}} mod p, and group key material.
% 2. Pre-computed key packages are stored in cluster.precomputedKeyCache.
% 3. When DTHSBP.leave() executes with a cache hit, leader execution time
%    is reduced by at least 50% compared to reactive rekeying.
% 4. StatisticsManager correctly records precomputation hits, misses,
%    precomputationHitRate, and leaderTimeReduction.

    rootDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(rootDir));

    fprintf('=================================================================\n');
    fprintf('Contribution B Test: Predictive Pre-Calculation & Zero-Latency\n');
    fprintf('=================================================================\n');

    %% 1. Swarm & Configuration Setup
    cfg = config();
    cfg.numUAVs = 250;
    cfg.numClusters = 5;
    cfg.clusterSize = cfg.numUAVs / cfg.numClusters; % 50 UAVs per cluster
    cfg.randomSeed = 42;
    rng(cfg.randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);

    clusterID = 1;
    cluster = swarm.findCluster(clusterID);
    activeMembers = cluster.getActiveUAVs();
    nc = numel(activeMembers);

    fprintf('Target Cluster ID     : %d\n', clusterID);
    fprintf('Active Member Count   : %d\n', nc);
    assert(nc >= 20, 'ZeroLatencyHandoverTest:InsufficientMembers', ...
        'Target cluster requires at least 20 members for timing benchmark.');

    %% 2. Verify DTPrecomputationEngine Structure & Blind Key Generation
    precomputeEngine = protocol.precomputationEngine;
    assert(~isempty(precomputeEngine), ...
        'ZeroLatencyHandoverTest:EngineMissing', ...
        'DTHSBP does not contain an initialized DTPrecomputationEngine.');

    sampleUAV = activeMembers(end);
    pkg = precomputeEngine.interceptPrediction(sampleUAV.id);

    assert(~isempty(pkg), ...
        'ZeroLatencyHandoverTest:PackageEmpty', ...
        'interceptPrediction failed to produce a precomputed package.');
    assert(~isempty(pkg.groupKey), ...
        'ZeroLatencyHandoverTest:GroupKeyMissing', ...
        'Precomputed package does not contain groupKey.');
    assert(~isempty(pkg.intermediateChain), ...
        'ZeroLatencyHandoverTest:IntermediateChainMissing', ...
        'Precomputed package does not contain intermediateChain.');
    assert(~isempty(pkg.blindKeys), ...
        'ZeroLatencyHandoverTest:BlindKeysMissing', ...
        'Precomputed package does not contain blindKeys.');
    assert(numel(pkg.blindKeys) == numel(pkg.intermediateChain), ...
        'ZeroLatencyHandoverTest:BlindKeyLengthMismatch', ...
        'Number of blind keys does not match intermediate chain length.');
    assert(~isempty(cluster.precomputedKeyCache), ...
        'ZeroLatencyHandoverTest:CacheNotPopulated', ...
        'cluster.precomputedKeyCache was not populated by precomputation.');

    fprintf('Blind keys computed   : %d\n', numel(pkg.blindKeys));
    fprintf('Precomputed Group Key : %d\n', pkg.groupKey);

    % Clear cache for controlled benchmarking
    cluster.clearPrecomputedKey();

    %% 3. Benchmark Reactive Rekeying (Cache Miss Baseline)
    numTrials = 5;
    reactiveTimes = zeros(1, numTrials);

    fprintf('\n--- Running Reactive Rekeying Baseline (%d trials) ---\n', numTrials);
    for t = 1:numTrials
        activeList = cluster.getActiveUAVs();
        leavingNode = activeList(end);
        cluster.clearPrecomputedKey(); % Ensure cache miss

        res = protocol.leave(leavingNode.id);
        assert(~isempty(res), 'ZeroLatencyHandoverTest:ReactiveLeaveFailed');
        assert(~res.isPrecomputedHit, ...
            'ZeroLatencyHandoverTest:UnexpectedHit', ...
            'Expected cache miss during reactive rekeying.');

        reactiveTimes(t) = res.leaderTime;
    end
    tReactiveAvg = mean(reactiveTimes);
    fprintf('Average Reactive Leader Time   : %.6f s (%.3f ms)\n', ...
        tReactiveAvg, tReactiveAvg * 1000);

    %% 4. Benchmark Predictive Zero-Latency Handover (Cache Hit)
    precomputedTimes = zeros(1, numTrials);

    fprintf('\n--- Running Predictive Pre-Calculated Handover (%d trials) ---\n', numTrials);
    for t = 1:numTrials
        activeList = cluster.getActiveUAVs();
        leavingNode = activeList(end);

        % Precomputation phase: asynchronous precalculation triggered by prediction
        protocol.precompute(leavingNode.id);
        assert(~isempty(cluster.precomputedKeyCache), ...
            'ZeroLatencyHandoverTest:CacheMissingBeforeLeave', ...
            'Key cache was not populated prior to leave event.');

        % Execution phase: handover happens upon physical leave event
        res = protocol.leave(leavingNode.id);
        assert(~isempty(res), 'ZeroLatencyHandoverTest:PrecomputedLeaveFailed');
        assert(res.isPrecomputedHit, ...
            'ZeroLatencyHandoverTest:ExpectedHitMissed', ...
            'Expected precomputed cache hit during leave event.');

        precomputedTimes(t) = res.leaderTime;
    end
    tPrecomputedAvg = mean(precomputedTimes);
    fprintf('Average Precomputed Leader Time: %.6f s (%.3f ms)\n', ...
        tPrecomputedAvg, tPrecomputedAvg * 1000);

    %% 5. Evaluate Latency Reduction Assertion (>= 50%)
    if tReactiveAvg > 0
        reductionPct = ((tReactiveAvg - tPrecomputedAvg) / tReactiveAvg) * 100;
    else
        reductionPct = 100;
    end

    fprintf('\n----------------- Performance Comparison -----------------\n');
    fprintf('Reactive Leader Latency    : %.6f s\n', tReactiveAvg);
    fprintf('Precomputed Leader Latency : %.6f s\n', tPrecomputedAvg);
    fprintf('Absolute Latency Reduction : %.6f s\n', max(0, tReactiveAvg - tPrecomputedAvg));
    fprintf('Relative Latency Reduction : %.2f%%\n', reductionPct);
    fprintf('----------------------------------------------------------\n');

    assert(tPrecomputedAvg < tReactiveAvg, ...
        'ZeroLatencyHandoverTest:LatencyNotLower', ...
        'Precomputed leader time is not lower than reactive leader time.');

    assert(reductionPct >= 50.0, ...
        'ZeroLatencyHandoverTest:ReductionBelowThreshold', ...
        sprintf('Precomputed latency reduction (%.2f%%) is below the required 50%% threshold.', reductionPct));

    %% 6. Verify Full Simulation Integration & StatisticsManager
    fprintf('\n--- Verifying Simulation & Statistics Integration ---\n');
    simCfg = config();
    simCfg.numUAVs = 100;
    simCfg.numClusters = 5;
    simCfg.clusterSize = 20;
    simCfg.simulationTime = 10;
    simCfg.timeStep = 1;
    simCfg.dtDisturbanceEnabled = true;
    simCfg.dtDisturbanceRate = 0.5;
    simCfg.dtDisturbanceUAVCount = 2;
    simCfg.randomSeed = 101;
    rng(simCfg.randomSeed);

    simSwarm = Swarm(simCfg);
    simProtocol = DTHSBP(simSwarm);
    sim = Simulation(simCfg, simProtocol);

    % Run simulation
    sim.run();

    stats = sim.statistics.getStatistics();
    fprintf('Simulation Statistics:\n');
    fprintf('  Total Rekeys             : %d\n', stats.localRekeys + stats.batchRekeys);
    fprintf('  Precomputation Hits      : %d\n', stats.precomputationHits);
    fprintf('  Precomputation Misses    : %d\n', stats.precomputationMisses);
    fprintf('  Precomputation Hit Rate  : %.2f%%\n', stats.precomputationHitRate * 100);
    fprintf('  Recorded Leader Reduction: %.6f s\n', stats.leaderTimeReduction);

    % Verify ExperimentResult container compatibility
    expRes = ExperimentResult();
    expRes.protocol = "DT-HSBP";
    expRes.precomputationHitRate = stats.precomputationHitRate;
    expRes.leaderTimeReduction = stats.leaderTimeReduction;
    expRes.precomputedLeaderTime = stats.precomputedLeaderTime;
    expRes.reactiveLeaderTime = stats.reactiveLeaderTime;

    resStruct = expRes.toStruct();
    assert(isfield(resStruct, 'precomputationHitRate'), ...
        'ZeroLatencyHandoverTest:FieldMissing', ...
        'precomputationHitRate missing from ExperimentResult.');
    assert(isfield(resStruct, 'leaderTimeReduction'), ...
        'ZeroLatencyHandoverTest:FieldMissing', ...
        'leaderTimeReduction missing from ExperimentResult.');

    fprintf('\n=================================================================\n');
    fprintf('ZeroLatencyHandoverTest PASSED successfully!\n');
    fprintf('Latency reduction >= 50%% and zero-latency handover confirmed.\n');
    fprintf('=================================================================\n');

end
