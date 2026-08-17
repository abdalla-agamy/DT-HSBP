function report = ExperimentR30Analysis(joinResults, leaveResults)
%EXPERIMENTR30ANALYSIS Analyze the final Join/Leave experiment data.
%
% REPORT = EXPERIMENTR30ANALYSIS(JOINRESULTS, LEAVERESULTS) validates and
% summarizes the official Join/Leave observations without modifying the raw data.
%
% Expected configuration:
%   Protocols   : FlatSBP, HSBP, DTHSBP
%   Swarm sizes : 1000, 2000, 3000, 4000, 5000
%   Repetitions : 10
%
% The function reports descriptive statistics, communication savings, and
% DT-HSBP predicted-leave consistency. It does not generate figures and it
% does not alter the supplied ExperimentResult data.

    if nargin ~= 2
        error('ExperimentR30Analysis:InvalidInput', ...
            'Provide Join and Leave result arrays.');
    end

    validateattributes(joinResults, {'struct'}, {'vector'}, mfilename, ...
        'joinResults');
    validateattributes(leaveResults, {'struct'}, {'vector'}, mfilename, ...
        'leaveResults');

    protocols = ["FlatSBP", "HSBP", "DTHSBP"];
    swarmSizes = [1000 2000 3000 4000 5000];
    repetitions = 10;

    validateStudy(joinResults, "Join", protocols, swarmSizes, repetitions);
    validateStudy(leaveResults, "Leave", protocols, swarmSizes, repetitions);

    joinStats = ExperimentStatistics.summarize(joinResults);
    leaveStats = ExperimentStatistics.summarize(leaveResults);

    report = struct();
    report.expectedProtocols = protocols;
    report.expectedSwarmSizes = swarmSizes;
    report.expectedRepetitions = repetitions;
    report.joinObservationCount = numel(joinResults);
    report.leaveObservationCount = numel(leaveResults);
    report.joinGroupCount = numel(joinStats);
    report.leaveGroupCount = numel(leaveStats);
    report.joinStatistics = joinStats;
    report.leaveStatistics = leaveStats;
    report.joinSavings = computeSavings(joinStats, protocols, swarmSizes);
    report.leaveSavings = computeSavings(leaveStats, protocols, swarmSizes);
    report.leaveDTDiagnostics = summarizeDTLeave(leaveResults, swarmSizes, repetitions);

    printReport(report);
end

function validateStudy(results, expectedEvent, protocols, swarmSizes, repetitions)
    required = {'eventType','protocol','swarmSize','runID','success', ...
        'status','messageCount','messageBytes','leaderTime','followerTime'};

    for i = 1:numel(required)
        if ~isfield(results, required{i})
            error('ExperimentR30Analysis:MissingField', ...
                'Missing required field: %s', required{i});
        end
    end

    events = string({results.eventType});
    if any(events ~= expectedEvent)
        error('ExperimentR30Analysis:EventMismatch', ...
            'Results contain an unexpected event type.');
    end

    if numel(results) ~= numel(protocols) * numel(swarmSizes) * repetitions
        error('ExperimentR30Analysis:ObservationCount', ...
            '%s study must contain exactly %d observations.', ...
            expectedEvent, numel(protocols) * numel(swarmSizes) * repetitions);
    end

    for p = 1:numel(protocols)
        for n = 1:numel(swarmSizes)
            mask = string({results.protocol}) == protocols(p) & ...
                   [results.swarmSize] == swarmSizes(n);
            group = results(mask);

            if numel(group) ~= repetitions
                error('ExperimentR30Analysis:GroupCount', ...
                    '%s/%s/N=%d must contain exactly %d observations.', ...
                    expectedEvent, protocols(p), swarmSizes(n), repetitions);
            end

            if any(~[group.success])
                error('ExperimentR30Analysis:UnsuccessfulObservation', ...
                    '%s/%s/N=%d contains unsuccessful observations.', ...
                    expectedEvent, protocols(p), swarmSizes(n));
            end

            runIDs = sort([group.runID]);
            if ~isequal(runIDs, 1:repetitions)
                error('ExperimentR30Analysis:RunIDs', ...
                    '%s/%s/N=%d must contain run IDs 1..%d.', ...
                    expectedEvent, protocols(p), swarmSizes(n), repetitions);
            end
        end
    end
end

function savings = computeSavings(stats, protocols, swarmSizes)
    savings = repmat(struct( ...
        'swarmSize', 0, ...
        'hsbpVsFlatMessageSavingPct', NaN, ...
        'dthsbpVsFlatMessageSavingPct', NaN, ...
        'dthsbpVsHsbpMessageSavingPct', NaN, ...
        'hsbpVsFlatByteSavingPct', NaN, ...
        'dthsbpVsFlatByteSavingPct', NaN, ...
        'dthsbpVsHsbpByteSavingPct', NaN), numel(swarmSizes), 1);

    for n = 1:numel(swarmSizes)
        flat = findStat(stats, protocols(1), swarmSizes(n));
        hsbp = findStat(stats, protocols(2), swarmSizes(n));
        dt = findStat(stats, protocols(3), swarmSizes(n));

        savings(n).swarmSize = swarmSizes(n);
        savings(n).hsbpVsFlatMessageSavingPct = pctSaving( ...
            flat.messageCount.mean, hsbp.messageCount.mean);
        savings(n).dthsbpVsFlatMessageSavingPct = pctSaving( ...
            flat.messageCount.mean, dt.messageCount.mean);
        savings(n).dthsbpVsHsbpMessageSavingPct = pctSaving( ...
            hsbp.messageCount.mean, dt.messageCount.mean);
        savings(n).hsbpVsFlatByteSavingPct = pctSaving( ...
            flat.messageBytes.mean, hsbp.messageBytes.mean);
        savings(n).dthsbpVsFlatByteSavingPct = pctSaving( ...
            flat.messageBytes.mean, dt.messageBytes.mean);
        savings(n).dthsbpVsHsbpByteSavingPct = pctSaving( ...
            hsbp.messageBytes.mean, dt.messageBytes.mean);
    end
end

function value = pctSaving(baseline, improved)
    if baseline == 0
        value = NaN;
    else
        value = 100 * (baseline - improved) / baseline;
    end
end

function stat = findStat(stats, protocol, swarmSize)
    mask = string({stats.protocol}) == protocol & ...
           [stats.swarmSize] == swarmSize;
    if sum(mask) ~= 1
        error('ExperimentR30Analysis:MissingStatistic', ...
            'Expected exactly one statistic for %s/N=%d.', protocol, swarmSize);
    end
    stat = stats(mask);
end

function diagnostics = summarizeDTLeave(results, swarmSizes, repetitions)
    required = {'predictedLeaves','rekeyCount','messageCount'};
    for i = 1:numel(required)
        if ~isfield(results, required{i})
            error('ExperimentR30Analysis:MissingDTField', ...
                'Missing required DT leave field: %s', required{i});
        end
    end

    dt = results(string({results.protocol}) == "DTHSBP");
    diagnostics = repmat(struct( ...
        'swarmSize', 0, ...
        'observations', 0, ...
        'minPredictedLeaves', NaN, ...
        'maxPredictedLeaves', NaN, ...
        'meanPredictedLeaves', NaN, ...
        'allSingleRekey', false), numel(swarmSizes), 1);

    for n = 1:numel(swarmSizes)
        group = dt([dt.swarmSize] == swarmSizes(n));
        if numel(group) ~= repetitions
            error('ExperimentR30Analysis:DTGroupCount', ...
                'DT-HSBP Leave/N=%d must contain %d observations.', ...
                swarmSizes(n), repetitions);
        end

        predicted = zeros(1, numel(group));
        for k = 1:numel(group)
            predicted(k) = numel(group(k).predictedLeaves);
        end

        diagnostics(n).swarmSize = swarmSizes(n);
        diagnostics(n).observations = numel(group);
        diagnostics(n).minPredictedLeaves = min(predicted);
        diagnostics(n).maxPredictedLeaves = max(predicted);
        diagnostics(n).meanPredictedLeaves = mean(predicted);
        diagnostics(n).allSingleRekey = all([group.rekeyCount] == 1);
    end
end

function printReport(report)
    fprintf('============================================\n');
    fprintf('R=10 Statistical Analysis\n');
    fprintf('============================================\n');
    fprintf('Join observations  : %d\n', report.joinObservationCount);
    fprintf('Join groups        : %d\n', report.joinGroupCount);
    fprintf('Leave observations : %d\n', report.leaveObservationCount);
    fprintf('Leave groups       : %d\n', report.leaveGroupCount);
    fprintf('\n');

    printStatistics('JOIN', report.joinStatistics);
    printStatistics('LEAVE', report.leaveStatistics);

    fprintf('\n--- LEAVE COMMUNICATION SAVINGS ---\n');
    fprintf('N        HSBP/Flat  DT/Flat    DT/HSBP\n');
    for i = 1:numel(report.leaveSavings)
        s = report.leaveSavings(i);
        fprintf('%-8d %-10.4f %-10.4f %-10.4f\n', s.swarmSize, ...
            s.hsbpVsFlatMessageSavingPct, ...
            s.dthsbpVsFlatMessageSavingPct, ...
            s.dthsbpVsHsbpMessageSavingPct);
    end

    fprintf('\n--- DT-HSBP LEAVE CONSISTENCY ---\n');
    fprintf('N        Obs.  MinPred  MaxPred  MeanPred  SingleRekey\n');
    for i = 1:numel(report.leaveDTDiagnostics)
        d = report.leaveDTDiagnostics(i);
        fprintf('%-8d %-5d %-8d %-8d %-9.4f %d\n', ...
            d.swarmSize, d.observations, d.minPredictedLeaves, ...
            d.maxPredictedLeaves, d.meanPredictedLeaves, d.allSingleRekey);
    end

    fprintf('============================================\n');
end

function printStatistics(titleText, stats)
    fprintf('--- %s STATISTICS ---\n', titleText);
    fprintf('Protocol N        MeanLeader(s) StdLeader(s) MeanFollower(s) StdFollower(s) MeanMsg\n');
    for i = 1:numel(stats)
        s = stats(i);
        fprintf('%-8s %-7d %-13.8g %-12.8g %-15.8g %-14.8g %-8.4g\n', ...
            s.protocol, s.swarmSize, s.leaderTime.mean, s.leaderTime.std, ...
            s.followerTime.mean, s.followerTime.std, s.messageCount.mean);
    end
end
