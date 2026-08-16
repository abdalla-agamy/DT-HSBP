function ExperimentSmokeTest()
%EXPERIMENTSMOKETEST Validate the controlled experimental pipeline.
%
%   This is a deliberately small smoke test. It exercises both Join and
%   Leave studies through the complete raw-result and statistics pipeline.
%
%   Scope:
%       3 protocols x 2 swarm sizes x 3 repetitions
%       = 18 observations per event type.
%
%   The test does not represent the paper's full experiment. It is intended
%   to detect structural, execution, reproducibility, and aggregation
%   errors before expensive studies are started.

    clc;

    %% Make the test independent of the current MATLAB path

    testFile = mfilename('fullpath');
    projectRoot = fileparts(testFile);
    addpath(genpath(projectRoot));

    %% Smoke-test configuration

    protocols = ["FlatSBP", "HSBP", "DTHSBP"];
    swarmSizes = [1000, 2000];
    repetitions = 3;
    clusterID = 1;
    baseSeed = 42;

    expectedCount = numel(protocols) * ...
        numel(swarmSizes) * repetitions;
    expectedGroupCount = numel(protocols) * numel(swarmSizes);

    fprintf('============================================\n');
    fprintf('Experiment Smoke Test\n');
    fprintf('============================================\n');
    fprintf('Protocols    : %s\n', strjoin(protocols, ', '));
    fprintf('Swarm sizes  : %s\n', mat2str(swarmSizes));
    fprintf('Repetitions  : %d\n', repetitions);
    fprintf('Cluster      : %d\n', clusterID);
    fprintf('Base seed    : %d\n', baseSeed);
    fprintf('Expected obs.: %d per event type\n\n', expectedCount);

    %% JOIN

    fprintf('--- JOIN STUDY ---\n');

    joinResults = runExperimentStudy( ...
        protocols, swarmSizes, "Join", repetitions, clusterID, baseSeed);

    validateRawResults(joinResults, protocols, swarmSizes, repetitions, ...
        "Join", expectedCount);

    joinStats = ExperimentStatistics.summarize(joinResults);

    validateStatistics(joinStats, protocols, swarmSizes, ...
        "Join", expectedGroupCount);

    printStatusSummary(joinResults, "Join");
    printStatisticsSummary(joinStats, "Join");

    %% LEAVE

    fprintf('\n--- LEAVE STUDY ---\n');

    leaveResults = runExperimentStudy( ...
        protocols, swarmSizes, "Leave", repetitions, clusterID, baseSeed);

    validateRawResults(leaveResults, protocols, swarmSizes, repetitions, ...
        "Leave", expectedCount);

    leaveStats = ExperimentStatistics.summarize(leaveResults);

    validateStatistics(leaveStats, protocols, swarmSizes, ...
        "Leave", expectedGroupCount);

    printStatusSummary(leaveResults, "Leave");
    printStatisticsSummary(leaveStats, "Leave");

    %% DT-HSBP leave diagnostics

    fprintf('\n--- DT-HSBP LEAVE DIAGNOSTICS ---\n');

    dtLeave = leaveResults( ...
        string({leaveResults.protocol}) == "DTHSBP");

    fprintf('DT-HSBP leave observations: %d\n', numel(dtLeave));

    for i = 1:numel(dtLeave)
        fprintf(['  run=%d, N=%d, success=%d, status=%s, ', ...
                 'rekeys=%g, messages=%g, predictedLeaves=%g\n'], ...
            dtLeave(i).runID, ...
            dtLeave(i).swarmSize, ...
            dtLeave(i).success, ...
            string(dtLeave(i).status), ...
            dtLeave(i).rekeyCount, ...
            dtLeave(i).messageCount, ...
            dtLeave(i).predictedLeaves);
    end

    %% Final result

    fprintf('\n============================================\n');
    fprintf('SMOKE TEST PASSED\n');
    fprintf('============================================\n');
    fprintf('Join observations : %d\n', numel(joinResults));
    fprintf('Join groups       : %d\n', numel(joinStats));
    fprintf('Leave observations: %d\n', numel(leaveResults));
    fprintf('Leave groups      : %d\n', numel(leaveStats));

end

function validateRawResults( ...
        results, protocols, swarmSizes, repetitions, eventType, expectedCount)

    assert(isstruct(results), ...
        '%s results must be a struct array.', eventType);

    assert(numel(results) == expectedCount, ...
        '%s returned %d observations; expected %d.', ...
        eventType, numel(results), expectedCount);

    requiredFields = { ...
        'protocol', 'eventType', 'runID', 'randomSeed', ...
        'success', 'status', 'swarmSize', ...
        'leaderTime', 'followerTime', ...
        'messageCount', 'messageBytes'};

    fields = fieldnames(results);

    for i = 1:numel(requiredFields)
        assert(ismember(requiredFields{i}, fields), ...
            'Missing required result field: %s.', requiredFields{i});
    end

    actualProtocols = unique(string({results.protocol}), 'stable');
    actualSizes = unique([results.swarmSize]);
    actualEvents = unique(string({results.eventType}));

    assert(isequal(sort(actualProtocols), sort(protocols)), ...
        '%s protocol set is incorrect.', eventType);
    assert(isequal(sort(actualSizes), sort(swarmSizes)), ...
        '%s swarm-size set is incorrect.', eventType);
    assert(isequal(actualEvents, string(eventType)), ...
        '%s event type is incorrect.', eventType);

    runIDs = [results.runID];
    assert(all(runIDs >= 1 & runIDs <= repetitions), ...
        '%s contains invalid run IDs.', eventType);

    %% Verify paired seeds within each repetition

    for r = 1:repetitions
        mask = runIDs == r;
        seeds = [results(mask).randomSeed];

        assert(~isempty(seeds), ...
            '%s repetition %d has no observations.', eventType, r);
        assert(all(seeds == seeds(1)), ...
            ['%s repetition %d does not use one common seed ', ...
             'across protocols/sizes.'], eventType, r);
    end

    %% Detect invalid successful measurements

    successful = results([results.success]);

    if ~isempty(successful)
        assert(all([successful.leaderTime] >= 0), ...
            '%s contains negative leader execution times.', eventType);
        assert(all([successful.followerTime] >= 0), ...
            '%s contains negative follower execution times.', eventType);
        assert(all([successful.messageCount] >= 0), ...
            '%s contains negative message counts.', eventType);
        assert(all([successful.messageBytes] >= 0), ...
            '%s contains negative message bytes.', eventType);
    end

    fprintf('Raw %s validation: PASS (%d observations).\n', ...
        eventType, numel(results));
end

function validateStatistics( ...
        statistics, protocols, swarmSizes, eventType, expectedGroupCount)

    assert(isstruct(statistics), ...
        '%s statistics must be a struct array.', eventType);
    assert(numel(statistics) == expectedGroupCount, ...
        '%s produced %d statistical groups; expected %d.', ...
        eventType, numel(statistics), expectedGroupCount);

    requiredFields = { ...
        'eventType', 'protocol', 'swarmSize', ...
        'attemptedCount', 'successfulCount', ...
        'rejectedCount', 'failedCount', ...
        'leaderTime', 'followerTime', ...
        'messageCount', 'messageBytes'};

    fields = fieldnames(statistics);

    for i = 1:numel(requiredFields)
        assert(ismember(requiredFields{i}, fields), ...
            'Missing statistics field: %s.', requiredFields{i});
    end

    actualProtocols = unique(string({statistics.protocol}), 'stable');
    actualSizes = unique([statistics.swarmSize]);
    actualEvents = unique(string({statistics.eventType}));

    assert(isequal(sort(actualProtocols), sort(protocols)), ...
        '%s statistics protocol set is incorrect.', eventType);
    assert(isequal(sort(actualSizes), sort(swarmSizes)), ...
        '%s statistics swarm-size set is incorrect.', eventType);
    assert(isequal(actualEvents, string(eventType)), ...
        '%s statistics event type is incorrect.', eventType);

    for i = 1:numel(statistics)
        s = statistics(i);

        assert(s.attemptedCount > 0, ...
            '%s group has zero attempted observations.', eventType);
        assert(s.successfulCount + s.rejectedCount + s.failedCount == ...
               s.attemptedCount, ...
            '%s group has inconsistent outcome counts.', eventType);

        if s.successfulCount > 0
            assert(~isnan(s.leaderTime.mean), ...
                '%s group has successful observations but NaN leader mean.', ...
                eventType);
            assert(~isnan(s.followerTime.mean), ...
                '%s group has successful observations but NaN follower mean.', ...
                eventType);
        end
    end

    fprintf('Statistics %s validation: PASS (%d groups).\n', ...
        eventType, numel(statistics));
end

function printStatusSummary(results, eventType)

    statuses = string({results.status});
    successCount = sum([results.success]);
    rejectedCount = sum(statuses == "Rejected");
    failedCount = sum(statuses == "Failed");

    fprintf('\n%s status summary:\n', eventType);
    fprintf('  Attempted : %d\n', numel(results));
    fprintf('  Successful: %d\n', successCount);
    fprintf('  Rejected  : %d\n', rejectedCount);
    fprintf('  Failed    : %d\n', failedCount);
end

function printStatisticsSummary(statistics, eventType)

    fprintf('\n%s statistics summary:\n', eventType);
    fprintf(['  %-8s %-8s %-9s %-9s %-9s ', ...
             'LeaderMean(s) FollowerMean(s)\n'], ...
        'Protocol', 'N', 'Attempted', 'Success', 'Rejected');

    for i = 1:numel(statistics)
        s = statistics(i);

        fprintf(['  %-8s %-8d %-9d %-9d %-9d ', ...
                 '%.6g        %.6g\n'], ...
            string(s.protocol), ...
            s.swarmSize, ...
            s.attemptedCount, ...
            s.successfulCount, ...
            s.rejectedCount, ...
            s.leaderTime.mean, ...
            s.followerTime.mean);
    end
end
