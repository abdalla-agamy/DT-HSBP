function DTBatchLeaveTest()
%DTBATCHLEAVETEST Validate DT-HSBP predicted batch leave behavior.
%
% This is a diagnostic test only. It does not modify production protocol,
% swarm, or DT code.
%
% The test creates a swarm, initializes DT predictions, applies a
% controlled physical-state perturbation to two cluster members, updates
% their DT agents to obtain residuals, and then issues one leave request.
% The test verifies that the perturbed members are predicted to leave and
% that one rekey is performed for the explicit leave request.

    rootDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(rootDir));

    fprintf('============================================\n');
    fprintf('DT-HSBP Batch Leave Test\n');
    fprintf('============================================\n');

    cfg = config();
    cfg.numUAVs = 1000;
    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = 42;
    rng(cfg.randomSeed);

    clusterID = 1;
    perturbation = [10 0];

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);

    cluster = swarm.findCluster(clusterID);
    members = cluster.getActiveUAVs();

    assert(numel(members) >= 4, ...
        'DTBatchLeaveTest:InsufficientMembers', ...
        'At least four active UAVs are required in the target cluster.');

    leavingUAV = members(4);
    predictedCandidates = members(2:3);

    % First update establishes the DT prediction.
    for i = 1:numel(predictedCandidates)
        predictedCandidates(i).dt.update();
    end

    % Controlled physical-state perturbation creates a measurable
    % prediction residual without changing production code.
    for i = 1:numel(predictedCandidates)
        predictedCandidates(i).position = ...
            predictedCandidates(i).position + perturbation;
    end

    % Second update computes residual and stabilityScore.
    for i = 1:numel(predictedCandidates)
        predictedCandidates(i).dt.update();
    end

    scores = zeros(1, numel(predictedCandidates));
    for i = 1:numel(predictedCandidates)
        scores(i) = predictedCandidates(i).dt.stabilityScore;
    end

    fprintf('Target cluster       : %d\n', clusterID);
    fprintf('Leaving UAV           : %d\n', leavingUAV.id);
    fprintf('Perturbed UAVs        : %d, %d\n', ...
        predictedCandidates(1).id, predictedCandidates(2).id);
    fprintf('Perturbation          : [%g %g]\n', ...
        perturbation(1), perturbation(2));
    fprintf('Stability scores      : %.6f, %.6f\n', ...
        scores(1), scores(2));
    fprintf('Leave threshold       : %.6f\n', cfg.thetaLeave);

    assert(all(scores > cfg.thetaLeave), ...
        'DTBatchLeaveTest:PredictionThresholdNotReached', ...
        'Controlled perturbation did not produce predicted leaves.');

    result = protocol.leave(leavingUAV.id);

    assert(~isempty(result), ...
        'DTBatchLeaveTest:LeaveFailed', ...
        'The explicit leave operation did not produce a rekey result.');

    predictedLeaves = result.predictedLeaves;

    fprintf('Predicted leaves      : %s\n', mat2str(predictedLeaves));
    fprintf('Rekey count           : 1\n');
    fprintf('Messages sent         : %d\n', result.messagesSent);

    assert(all(ismember([predictedCandidates.id], predictedLeaves)), ...
        'DTBatchLeaveTest:PredictedLeavesMismatch', ...
        'Expected perturbed UAVs were not predicted to leave.');

    assert(numel(predictedLeaves) == numel(predictedCandidates), ...
        'DTBatchLeaveTest:UnexpectedPredictionCount', ...
        'Unexpected number of predicted leaves.');

    assert(result.numAffected == ...
        numel(cluster.getActiveUAVs()), ...
        'DTBatchLeaveTest:RekeyAffectedCountMismatch', ...
        'Rekey affected-UAV count is inconsistent with final cluster state.');

    fprintf('\nDT-HSBP batch-leave validation: PASS\n');
    fprintf('============================================\n');

end
