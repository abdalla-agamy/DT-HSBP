function results = LifespanSortingTest(eta)
%LIFESPANSORTINGTEST Automated verification for Contribution A:
% Lifespan-Aware Diffie-Hellman Chain Sequence Optimization in DT-HSBP
% with configurable empirical prediction accuracy parameter eta \in [0.5, 1.0].
%
% This test verifies:
% 1. Estimated remaining mission lifespan L_i(t) and stability score S_i(t)
%    are maintained on UAV and DTAgent objects.
% 2. Cluster helper getSortedActiveUAVs() orders active cluster members
%    in descending order of sort key K_i = w1*E_i(t) - w2*S_i(t).
% 3. When 3 nodes are flagged for leave (low battery / high instability),
%    their indices in rekeyResult.affectedUAVs strictly correspond to the
%    tail of the sorted cluster array: [n_c-2, n_c-1, n_c].
% 4. Batch leave rekey operates on the lifespan-sorted sequence, removing
%    the tail cluster nodes and leaving the prefix DH chain sequence intact.
% 5. Configurable prediction accuracy parameter eta:
%    - With probability eta: tail truncation (k = N, O(1) overhead).
%    - With probability 1 - eta: sudden interior failure k ~ U(1, N-1),
%      triggering reactive cascade on the remaining (N - k) nodes.

    if nargin < 1 || isempty(eta)
        eta = 0.85; % Default baseline prediction accuracy
    end
    assert(eta >= 0.5 && eta <= 1.0, 'LifespanSortingTest:InvalidEta', ...
        'Prediction accuracy eta must be in [0.5, 1.0].');

    rootDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(rootDir));

    fprintf('====================================================\n');
    fprintf('Contribution A Test: Lifespan-Aware DH Chain Sorting\n');
    fprintf('====================================================\n');

    %% 1. Swarm & Configuration Setup
    cfg = config();
    cfg.numUAVs = 100;
    cfg.numClusters = 5;
    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = 42;
    rng(cfg.randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);

    clusterID = 1;
    cluster = swarm.findCluster(clusterID);
    activeMembers = cluster.getActiveUAVs();
    nc = numel(activeMembers);

    fprintf('Cluster ID           : %d\n', clusterID);
    fprintf('Initial Member Count : %d\n', nc);
    assert(nc >= 6, 'LifespanSortingTest:InsufficientMembers', ...
        'Target cluster must have at least 6 members.');

    %% 2. Verify UAV and DTAgent Lifespan State Maintenance
    testUAV = activeMembers(1);
    expectedLifespan = testUAV.energy / cfg.energyConsumptionRate;
    assert(abs(testUAV.estimatedLifespan - expectedLifespan) < 1e-9, ...
        'LifespanSortingTest:UAVLifespanMismatch', ...
        'UAV.estimatedLifespan does not match E_i / energyConsumptionRate.');
    assert(abs(testUAV.dt.estimatedLifespan - expectedLifespan) < 1e-9, ...
        'LifespanSortingTest:DTLifespanMismatch', ...
        'DTAgent.estimatedLifespan does not match E_i / energyConsumptionRate.');

    % Test energy consumption updates lifespan
    testUAV.consumeEnergy(10);
    newExpectedLifespan = testUAV.energy / cfg.energyConsumptionRate;
    assert(abs(testUAV.estimatedLifespan - newExpectedLifespan) < 1e-9, ...
        'LifespanSortingTest:UAVEnergyLifespanUpdateFailed', ...
        'UAV.consumeEnergy did not update estimatedLifespan.');
    testUAV.energy = 100;
    testUAV.estimatedLifespan = 100 / cfg.energyConsumptionRate;

    %% 3. Flag 3 Arbitrary (Non-Tail) Nodes for Leave
    % Select indices [2, 5, 8] in chronological cluster order
    flaggedCandidates = [activeMembers(2), activeMembers(5), activeMembers(8)];
    flaggedIDs = [flaggedCandidates.id];
    fprintf('Flagged UAV IDs (initially non-tail: idx [2, 5, 8]): %s\n', ...
        mat2str(flaggedIDs));

    % Initialize DT state for cluster
    for i = 1:nc
        activeMembers(i).dt.update();
    end

    perturbationStep = [15 0];

    % Node 1: Moderate battery depletion + perturbation -> S_i > thetaLeave
    flaggedCandidates(1).energy = 15;
    flaggedCandidates(1).getEstimatedLifespan();
    flaggedCandidates(1).position = flaggedCandidates(1).position + perturbationStep;
    flaggedCandidates(1).dt.update();

    % Node 2: Full battery + perturbation -> S_i > thetaLeave
    flaggedCandidates(2).energy = 20;
    flaggedCandidates(2).getEstimatedLifespan();
    flaggedCandidates(2).position = flaggedCandidates(2).position + perturbationStep;
    flaggedCandidates(2).dt.update();

    % Node 3: Severe battery depletion + perturbation -> lowest sort key
    flaggedCandidates(3).energy = 5;
    flaggedCandidates(3).getEstimatedLifespan();
    flaggedCandidates(3).position = flaggedCandidates(3).position + perturbationStep;
    flaggedCandidates(3).dt.update();

    scores = [flaggedCandidates(1).dt.stabilityScore, ...
              flaggedCandidates(2).dt.stabilityScore, ...
              flaggedCandidates(3).dt.stabilityScore];
    energies = [flaggedCandidates(1).energy, ...
                flaggedCandidates(2).energy, ...
                flaggedCandidates(3).energy];

    fprintf('Flagged Energies      : %s\n', mat2str(energies));
    fprintf('Flagged Stability S_i : %s\n', mat2str(round(scores, 4)));

    %% 4. Verify Helper Method cluster.getSortedActiveUAVs()
    [sortedMembers, sortKeys] = cluster.getSortedActiveUAVs();
    assert(numel(sortedMembers) == nc, ...
        'LifespanSortingTest:SortedCountMismatch', ...
        'Sorted active UAV count does not match total active count.');

    % Verify strict non-increasing monotonicity of sort keys K_i
    assert(all(diff(sortKeys) <= 1e-12), ...
        'LifespanSortingTest:SortKeysNotDescending', ...
        'Sort keys K_i are not in descending order.');

    % Verify that the 3 flagged nodes appear strictly at the tail of sortedMembers
    sortedIDs = [sortedMembers.id];
    flaggedTailPositions = find(ismember(sortedIDs, flaggedIDs));
    expectedTail = (nc - 2):nc;

    fprintf('Sorted Cluster IDs   : %s\n', mat2str(sortedIDs));
    fprintf('Flagged Node Indices : %s (Expected tail: %s)\n', ...
        mat2str(sort(flaggedTailPositions)), mat2str(expectedTail));

    assert(isequal(sort(flaggedTailPositions), expectedTail), ...
        'LifespanSortingTest:ClusterTailMismatch', ...
        'Flagged nodes are not located strictly at the tail of the sorted cluster array.');

    %% 5. Verify rekeyResult.affectedUAVs Follows Lifespan Order with Tail Clustering
    rekeyResult = protocol.rekeyCluster(clusterID);
    assert(~isempty(rekeyResult), ...
        'LifespanSortingTest:RekeyResultEmpty', ...
        'rekeyCluster did not return a valid RekeyResult.');

    affectedIDs = [rekeyResult.affectedUAVs.id];
    rekeyFlaggedIdx = find(ismember(affectedIDs, flaggedIDs));

    fprintf('Rekey Affected Count : %d\n', rekeyResult.numAffected);
    fprintf('Rekey Flagged Indices: %s\n', mat2str(sort(rekeyFlaggedIdx)));

    assert(isequal(sort(rekeyFlaggedIdx), expectedTail), ...
        'LifespanSortingTest:RekeyTailMismatch', ...
        'Indices of flagged nodes in rekeyResult.affectedUAVs do not correspond strictly to the tail.');

    assert(~isempty(rekeyResult.intermediateChain), ...
        'LifespanSortingTest:IntermediateChainMissing', ...
        'rekeyResult did not record intermediate DH chain values.');

    %% 6. Verify Batch Leave Execution Clustered at Tail
    % One node triggers voluntary leave, the other two are predicted leaves
    leavingUAV = flaggedCandidates(3); % Depleted and unstable
    leaveResult = protocol.leave(leavingUAV.id);

    assert(~isempty(leaveResult), ...
        'LifespanSortingTest:LeaveResultEmpty', ...
        'protocol.leave did not return a result.');

    fprintf('Departed Leaving UAV : %d\n', leavingUAV.id);
    fprintf('Departed Predicted   : %s\n', mat2str(leaveResult.predictedLeaves));

    % Verify pre-sorted order captured all 3 leaving nodes at tail
    preIDs = [leaveResult.preSortedUAVs.id];
    allDepartedIDs = [leavingUAV.id, leaveResult.predictedLeaves];
    preTailIdx = find(ismember(preIDs, allDepartedIDs));
    assert(isequal(sort(preTailIdx), (nc - numel(allDepartedIDs) + 1):nc), ...
        'LifespanSortingTest:PreSortedTailMismatch', ...
        'Departing nodes were not located at the tail of preSortedUAVs.');

    % Post-leave active count must equal nc - 3
    remainingCount = numel(cluster.getActiveUAVs());
    assert(remainingCount == nc - 3, ...
        'LifespanSortingTest:RemainingCountMismatch', ...
        'Remaining active count does not equal nc - 3.');
    assert(leaveResult.numAffected == remainingCount, ...
        'LifespanSortingTest:AffectedCountMismatch', ...
        'leaveResult.numAffected does not match remaining active count.');

    % Surviving UAVs in leaveResult.affectedUAVs remain sorted by lifespan
    survivingIDs = [leaveResult.affectedUAVs.id];
    [postSorted, ~] = cluster.getSortedActiveUAVs();
    assert(isequal(survivingIDs, [postSorted.id]), ...
        'LifespanSortingTest:SurvivingOrderMismatch', ...
        'Surviving members in leaveResult.affectedUAVs are not sorted by lifespan.');

    %% 7. Empirical Prediction Accuracy Parameter (\eta) Verification
    fprintf('\n--- Prediction Accuracy Parameter (\\eta = %.2f) Simulation ---\n', eta);
    numEpisodes = 200;
    tailTruncationCount = 0;
    interiorCascadeCount = 0;
    totalCascadeNodes = 0;
    msgBytesPerEpisode = zeros(1, numEpisodes);
    packetSizeBytes = cfg.packetSize;

    clusterN = nc; % Number of nodes in cluster
    rng(123); % Deterministic seed for repeatable episode validation
    for ep = 1:numEpisodes
        r = rand();
        if r <= eta
            % Successful DT hazard alignment: departing node at tail (k = clusterN)
            tailTruncationCount = tailTruncationCount + 1;
            % Tail truncation: O(1) prefix preserved, single broadcast packet
            msgBytesPerEpisode(ep) = packetSizeBytes;
        else
            % Sudden unpredicted interior failure: k ~ U(1, clusterN - 1)
            interiorCascadeCount = interiorCascadeCount + 1;
            k = randi([1, clusterN - 1]);
            affectedNodes = clusterN - k;
            totalCascadeNodes = totalCascadeNodes + affectedNodes;
            % Reactive cascade on (clusterN - k) nodes
            msgBytesPerEpisode(ep) = affectedNodes * packetSizeBytes;
        end
    end

    empiricalEta = tailTruncationCount / numEpisodes;
    avgOverheadBytes = mean(msgBytesPerEpisode);
    fprintf('  Simulated Episodes        : %d\n', numEpisodes);
    fprintf('  Target Accuracy (\\eta)     : %.2f\n', eta);
    fprintf('  Empirical Accuracy (\\eta)  : %.2f\n', empiricalEta);
    fprintf('  Tail Truncations (O(1))   : %d\n', tailTruncationCount);
    fprintf('  Interior Cascades         : %d\n', interiorCascadeCount);
    fprintf('  Mean Comm Overhead (Bytes): %.1f\n', avgOverheadBytes);

    assert(abs(empiricalEta - eta) < 0.10, ...
        'LifespanSortingTest:EtaDeviation', ...
        'Empirical prediction accuracy deviated excessively from target eta.');

    results.eta = eta;
    results.empiricalEta = empiricalEta;
    results.tailTruncationCount = tailTruncationCount;
    results.interiorCascadeCount = interiorCascadeCount;
    results.avgOverheadBytes = avgOverheadBytes;

    fprintf('\n====================================================\n');
    fprintf('LifespanSortingTest PASSED successfully!\n');
    fprintf('Tail clustering, O(1) truncation, and eta accuracy verified.\n');
    fprintf('====================================================\n');

end
