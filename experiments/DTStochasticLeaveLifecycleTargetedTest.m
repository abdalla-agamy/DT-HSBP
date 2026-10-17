function report = DTStochasticLeaveLifecycleTargetedTest()
%DTSTOCHASTICLEAVELIFECYCLETARGETEDTEST Targeted tests for DT Leave lifecycle.
%
% Validates the 10 requirements from Step 6 of the Handover guide:
% 1. A single stochastic Leave episode.
% 2. A prediction that is realized.
% 3. A prediction that is not realized.
% 4. A stale prediction whose UAV is already inactive.
% 5. Multiple predicted departures in one cluster.
% 6. Predicted departures in different clusters.
% 7. Correct batch-rekey and local-rekey accounting.
% 8. No duplicate membership removals.
% 9. Conservation of prediction counts.
% 10. Consistent message and byte accounting.

    fprintf('====================================================\n');
    fprintf('Targeted Tests: DT Stochastic Leave Lifecycle\n');
    fprintf('====================================================\n');

    cfg = config();
    swarmSize = 1000;
    cfg.numUAVs = swarmSize;
    cfg.clusterSize = swarmSize / cfg.numClusters;

    % ----------------------------------------------------
    % Test 1: Single stochastic Leave episode
    % ----------------------------------------------------
    fprintf('Test 1: Single stochastic Leave episode...\n');
    resDT = runStochasticLeaveEpisode("DTHSBP", swarmSize, 1, 1, 42);
    resHSBP = runStochasticLeaveEpisode("HSBP", swarmSize, 1, 1, 42);
    resFlat = runStochasticLeaveEpisode("FlatSBP", swarmSize, 1, 1, 42);

    assert(resDT.success && resHSBP.success && resFlat.success, 'Test 1 failed: run failure');
    assert(resDT.batchRekeys == 1, 'Test 1 failed: DTHSBP should execute 1 batch rekey');
    assert(resHSBP.localRekeys == resDT.actualDepartures, 'Test 1 failed: HSBP should execute local rekeys equal to departures');
    assert(resDT.messageCount < resHSBP.messageCount, 'Test 1 failed: DTHSBP message count should be less than HSBP');
    assert(resHSBP.messageCount < resFlat.messageCount, 'Test 1 failed: HSBP message count should be less than FlatSBP');
    fprintf('  PASS: DT msgs=%d, HSBP msgs=%d, Flat msgs=%d (Departures=%d)\n', ...
        resDT.messageCount, resHSBP.messageCount, resFlat.messageCount, resDT.actualDepartures);

    % ----------------------------------------------------
    % Test 2: A prediction that is realized
    % ----------------------------------------------------
    fprintf('Test 2: A prediction that is realized...\n');
    cfg2 = cfg;
    cfg2.dtPredictedDepartureProbability = 1.0; % Force realization
    swarm2 = Swarm(cfg2);
    prot2 = DTHSBP(swarm2);
    sim2 = Simulation(cfg2, prot2);
    sim2.updateDigitalTwins();
    uavReal = swarm2.findUAV(2);
    uavReal.position = uavReal.position + [10 0];
    sim2.updateDigitalTwins();
    assert(uavReal.dt.predictedLeave, 'Test 2 failed: prediction not created');
    pReal = sim2.computeDTDepartureProbability(uavReal.dt.stabilityScore, cfg2.predictionHorizon);
    assert(pReal == 1.0, 'Test 2 failed: realization probability should be 1.0');
    sim2.schedulePredictedDepartures();
    stats2 = sim2.statistics.getStatistics();
    assert(stats2.dtPredictionsRealized >= 1, 'Test 2 failed: prediction not realized in accounting');
    fprintf('  PASS: Realized prediction confirmed with P=1.0\n');

    % ----------------------------------------------------
    % Test 3: A prediction that is not realized
    % ----------------------------------------------------
    fprintf('Test 3: A prediction that is not realized...\n');
    cfg3 = cfg;
    cfg3.dtPredictedDepartureProbability = 0.0; % Force unrealization
    swarm3 = Swarm(cfg3);
    prot3 = DTHSBP(swarm3);
    sim3 = Simulation(cfg3, prot3);
    sim3.updateDigitalTwins();
    uavUnreal = swarm3.findUAV(2);
    uavUnreal.position = uavUnreal.position + [10 0];
    sim3.updateDigitalTwins();
    assert(uavUnreal.dt.predictedLeave, 'Test 3 failed: prediction not created');
    pUnreal = sim3.computeDTDepartureProbability(uavUnreal.dt.stabilityScore, cfg3.predictionHorizon);
    assert(pUnreal == 0.0, 'Test 3 failed: realization probability should be 0.0');
    sim3.schedulePredictedDepartures();
    assert(~uavUnreal.dt.predictedLeave, 'Test 3 failed: unrealized prediction should be cancelled');
    fprintf('  PASS: Unrealized prediction cancelled and not scheduled\n');

    % ----------------------------------------------------
    % Test 4: A stale prediction whose UAV is already inactive
    % ----------------------------------------------------
    fprintf('Test 4: Stale prediction whose UAV is already inactive...\n');
    cfg4 = cfg;
    swarm4 = Swarm(cfg4);
    prot4 = DTHSBP(swarm4);
    sim4 = Simulation(cfg4, prot4);
    staleUAV = swarm4.findUAV(10);
    swarm4.removeUAV(10); % Deactivate UAV beforehand
    staleEvt = DTPredictedDepartureEvent(sim4.currentTime, 10, "StaleTest");
    staleEvt.execute(sim4); % Should safely return without error or rekey
    stats4 = sim4.statistics.getStatistics();
    assert(stats4.leaveEvents == 0, 'Test 4 failed: stale prediction caused leave execution');
    assert(stats4.totalMessages == 0, 'Test 4 failed: stale prediction generated messages');
    fprintf('  PASS: Stale prediction safely handled as no-op\n');

    % ----------------------------------------------------
    % Test 5: Multiple predicted departures in one cluster
    % ----------------------------------------------------
    fprintf('Test 5: Multiple predicted departures in one cluster...\n');
    cfg5 = cfg;
    swarm5 = Swarm(cfg5);
    prot5 = DTHSBP(swarm5);
    sim5 = Simulation(cfg5, prot5);
    sim5.updateDigitalTwins();
    cluster1 = swarm5.findCluster(1);
    members1 = cluster1.getActiveUAVs();
    u1 = members1(2); u2 = members1(3); u3 = members1(4);
    u1.position = u1.position + [10 0];
    u2.position = u2.position + [10 0];
    sim5.updateDigitalTwins();
    % Trigger leave on u3
    sim5.processLeaveRequest(u3.id, "leave");
    stats5 = sim5.statistics.getStatistics();
    assert(stats5.batchRekeys == 1, 'Test 5 failed: expected 1 batch rekey for multiple leaves');
    assert(~u1.active && ~u2.active && ~u3.active, 'Test 5 failed: all 3 UAVs should be removed');
    fprintf('  PASS: Multiple predicted departures batched into 1 rekey\n');

    % ----------------------------------------------------
    % Test 6: Predicted departures in different clusters
    % ----------------------------------------------------
    fprintf('Test 6: Predicted departures in different clusters...\n');
    cfg6 = cfg;
    swarm6 = Swarm(cfg6);
    prot6 = DTHSBP(swarm6);
    sim6 = Simulation(cfg6, prot6);
    sim6.updateDigitalTwins();
    uC1 = swarm6.findCluster(1).getActiveUAVs();
    uC2 = swarm6.findCluster(2).getActiveUAVs();
    uC1(2).position = uC1(2).position + [10 0];
    uC2(2).position = uC2(2).position + [10 0];
    sim6.updateDigitalTwins();
    sim6.processLeaveRequest(uC1(1).id, "leave");
    sim6.processLeaveRequest(uC2(1).id, "leave");
    stats6 = sim6.statistics.getStatistics();
    assert(stats6.batchRekeys == 2, 'Test 6 failed: expected 2 separate batch rekeys for 2 clusters');
    fprintf('  PASS: Departures in separate clusters maintain localized batch rekeys\n');

    % ----------------------------------------------------
    % Test 7: Correct batch-rekey and local-rekey accounting
    % ----------------------------------------------------
    fprintf('Test 7: Correct batch-rekey and local-rekey accounting...\n');
    assert(resDT.batchRekeys == 1 && resDT.localRekeys == 0, ...
        'Test 7 failed: DTHSBP should record 1 batch rekey and 0 local rekeys');
    assert(resHSBP.localRekeys == resDT.actualDepartures && resHSBP.batchRekeys == 0, ...
        'Test 7 failed: HSBP should record local rekeys and 0 batch rekeys');
    fprintf('  PASS: Batch and local rekeys correctly accounted\n');

    % ----------------------------------------------------
    % Test 8: No duplicate membership removals
    % ----------------------------------------------------
    fprintf('Test 8: No duplicate membership removals...\n');
    initialCount = swarm5.totalUAVs();
    activeCount = swarm5.activeUAVs();
    assert(initialCount - activeCount == 3, 'Test 8 failed: exactly 3 UAVs should have been removed');
    % Calling leave again on u1 should be safe no-op
    sim5.processLeaveRequest(u1.id, "leave");
    assert(swarm5.activeUAVs() == activeCount, 'Test 8 failed: duplicate leave changed active count');
    fprintf('  PASS: No duplicate removals\n');

    % ----------------------------------------------------
    % Test 9: Conservation of prediction counts
    % ----------------------------------------------------
    fprintf('Test 9: Conservation of prediction counts...\n');
    assert(resDT.predictionsCreated == resDT.predictionsRealized + resDT.predictionsUnrealized, ...
        'Test 9 failed: created != realized + unrealized');
    fprintf('  PASS: Conservation of predictions holds: %d = %d + %d\n', ...
        resDT.predictionsCreated, resDT.predictionsRealized, resDT.predictionsUnrealized);

    % ----------------------------------------------------
    % Test 10: Consistent message and byte accounting
    % ----------------------------------------------------
    fprintf('Test 10: Consistent message and byte accounting...\n');
    expectedBytesDT = resDT.messageCount * cfg.messageSize;
    expectedBytesHSBP = resHSBP.messageCount * cfg.messageSize;
    assert(resDT.messageBytes == expectedBytesDT, 'Test 10 failed: DTHSBP byte mismatch');
    assert(resHSBP.messageBytes == expectedBytesHSBP, 'Test 10 failed: HSBP byte mismatch');
    fprintf('  PASS: Byte accounting matches messageCount * messageSize (%d bytes/msg)\n', cfg.messageSize);

    report.allPassed = true;
    fprintf('\n====================================================\n');
    fprintf('ALL 10 TARGETED LIFECYCLE TESTS PASSED!\n');
    fprintf('====================================================\n');
end
