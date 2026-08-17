function report = DTPredictionConsumptionTest(protocolName, swarmSize, randomSeed)
%DTPREDICTIONCONSUMPTIONTEST Validate persistent DT prediction consumption.
%
% This test verifies that a DT prediction created by a physical
% disturbance is persistent until the corresponding DTHSBP leave/failure
% processing consumes it, and that the same prediction is not counted a
% second time.

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
        error('DTPredictionConsumptionTest:Protocol', ...
            'This test targets DTHSBP only.');
    end

    cfg = config();
    cfg.numUAVs = swarmSize;
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
        error('DTPredictionConsumptionTest:Population', ...
            'Target cluster must contain at least four active UAVs.');
    end

    disturbedIDs = [members(2).id, members(3).id];
    leavingID = members(4).id;

    disturbanceTime = sim.currentTime;
    perturbation = [10 0];

    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        uav.position = uav.position + perturbation;
    end

    sim.swarm.step(cfg);
    sim.currentTime = sim.currentTime + cfg.timeStep;
    sim.cfg.currentTime = sim.currentTime;
    sim.updateDigitalTwins();

    preConsume = false(1,numel(disturbedIDs));
    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        preConsume(i) = uav.dt.hasPredictedLeave(sim.currentTime);
    end

    sim.processLeaveRequest(leavingID);
    afterFirst = sim.statistics.getStatistics();

    postConsume = false(1,numel(disturbedIDs));
    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        if ~isempty(uav)
            postConsume(i) = uav.dt.hasPredictedLeave(sim.currentTime);
        end
    end

    firstBatch = afterFirst.batchRekeys;
    firstPredictedLeaves = afterFirst.predictedLeaves;

    sim.processLeaveRequest(leavingID);
    afterSecond = sim.statistics.getStatistics();

    secondBatch = afterSecond.batchRekeys;
    secondPredictedLeaves = afterSecond.predictedLeaves;

    report = struct();
    report.protocol = string(protocolName);
    report.swarmSize = swarmSize;
    report.randomSeed = randomSeed;
    report.targetCluster = targetCluster;
    report.disturbedUAVs = disturbedIDs;
    report.leavingUAV = leavingID;
    report.disturbanceTime = disturbanceTime;
    report.perturbation = perturbation;
    report.predictionsBeforeConsumption = preConsume;
    report.predictionsAfterConsumption = postConsume;
    report.firstBatchRekeys = firstBatch;
    report.firstPredictedLeaves = firstPredictedLeaves;
    report.secondBatchRekeys = secondBatch;
    report.secondPredictedLeaves = secondPredictedLeaves;

    report.predictionsCreated = all(preConsume);
    report.predictionsConsumed = ~any(postConsume);
    report.singleBatchFirstProcessing = (firstBatch == 1);
    report.noDuplicateBatchOnSecondProcessing = (secondBatch == firstBatch);
    report.noDuplicatePredictions = (secondPredictedLeaves == firstPredictedLeaves);

    fprintf('============================================\n');
    fprintf('DT Prediction Consumption Test\n');
    fprintf('============================================\n');
    fprintf('Protocol                 : %s\n', report.protocol);
    fprintf('Initial UAVs             : %d\n', swarmSize);
    fprintf('Disturbed UAVs           : %s\n', mat2str(disturbedIDs));
    fprintf('Leaving UAV              : %d\n', leavingID);
    fprintf('Predictions before leave : %s\n', mat2str(preConsume));
    fprintf('Predictions after leave  : %s\n', mat2str(postConsume));
    fprintf('First predicted leaves   : %d\n', firstPredictedLeaves);
    fprintf('First batch rekeys       : %d\n', firstBatch);
    fprintf('Second predicted leaves  : %d\n', secondPredictedLeaves);
    fprintf('Second batch rekeys      : %d\n', secondBatch);

    if ~(report.predictionsCreated && ...
            report.predictionsConsumed && ...
            report.singleBatchFirstProcessing && ...
            report.noDuplicateBatchOnSecondProcessing && ...
            report.noDuplicatePredictions)
        error('DTPredictionConsumptionTest:Failed', ...
            'Persistent DT prediction consumption validation failed.');
    end

    fprintf('DT persistent prediction validation: PASS\n');
    fprintf('============================================\n');
end
