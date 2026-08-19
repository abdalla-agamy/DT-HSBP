function report = ComparativeStochasticStudyTest(swarmSizes, repetitions, baseSeed)
%COMPARATIVESTOCHASTICSTUDYTEST Validate paired HSBP/DTHSBP stochastic study design.
%
% Each protocol receives the same swarm size, repetition ID, and random seed.
% The test verifies pairing, equality of exogenous workloads, and result
% completeness before any performance-gain claims are made.

    if nargin < 1 || isempty(swarmSizes)
        swarmSizes = [1000 2000];
    end
    if nargin < 2 || isempty(repetitions)
        repetitions = 3;
    end
    if nargin < 3 || isempty(baseSeed)
        baseSeed = 42;
    end

    swarmSizes = swarmSizes(:).';
    protocols = ["HSBP","DTHSBP"];

    if any(mod(swarmSizes,1) ~= 0) || any(swarmSizes < 1)
        error('ComparativeStochasticStudyTest:SwarmSizes', ...
            'swarmSizes must contain positive integers.');
    end
    if repetitions < 1 || mod(repetitions,1) ~= 0
        error('ComparativeStochasticStudyTest:Repetitions', ...
            'repetitions must be a positive integer.');
    end
    if baseSeed < 0 || mod(baseSeed,1) ~= 0
        error('ComparativeStochasticStudyTest:BaseSeed', ...
            'baseSeed must be a non-negative integer.');
    end

    results = runStochasticStudy(protocols,swarmSizes,repetitions,baseSeed);

    protocolValues = string({results.protocol});
    totalRuns = numel(swarmSizes) * repetitions;

    required = {'protocol','initialSwarmSize','runID','randomSeed', ...
        'generatedJoinEvents','generatedLeaveEvents','generatedFailureEvents', ...
        'dtDisturbanceCount','totalMessages','totalBytes', ...
        'localRekeys','batchRekeys','success'};

    fieldsPresent = all(cellfun(@(f)isfield(results,f),required));
    successful = all([results.success]);

    pairInvariant = true;
    workloadInvariant = true;
    dtOnlyInvariant = true;

    for n = 1:numel(swarmSizes)
        for r = 1:repetitions
            hMask = protocolValues == "HSBP" & ...
                [results.initialSwarmSize] == swarmSizes(n) & ...
                [results.runID] == r;
            dMask = protocolValues == "DTHSBP" & ...
                [results.initialSwarmSize] == swarmSizes(n) & ...
                [results.runID] == r;

            h = results(hMask);
            d = results(dMask);

            if numel(h) ~= 1 || numel(d) ~= 1
                pairInvariant = false;
                continue;
            end

            pairInvariant = pairInvariant && ...
                (h.randomSeed == d.randomSeed) && ...
                (h.initialSwarmSize == d.initialSwarmSize) && ...
                (h.runID == d.runID);

            % Compare the exogenous workload, not executed membership events.
            % Executed counts may legitimately diverge because a realized
            % DT-predicted departure changes the membership state.
            workloadInvariant = workloadInvariant && ...
                (h.generatedJoinEvents == d.generatedJoinEvents) && ...
                (h.generatedLeaveEvents == d.generatedLeaveEvents) && ...
                (h.generatedFailureEvents == d.generatedFailureEvents) && ...
                (h.dtDisturbanceCount == d.dtDisturbanceCount);

            % HSBP may still compute DT observations/predictions because the
            % Digital Twin layer is available to the simulation. What must be
            % absent is DT-driven departure realization/materialization.
            dtOnlyInvariant = dtOnlyInvariant && ...
                (h.dtPredictionsRealized == 0) && ...
                (h.predictedLeaves == 0);
        end
    end

    report = struct();
    report.swarmSizes = swarmSizes;
    report.repetitions = repetitions;
    report.baseSeed = baseSeed;
    report.totalResults = numel(results);
    report.expectedResults = 2 * totalRuns;
    report.requiredFieldsPresent = fieldsPresent;
    report.allRunsSuccessful = successful;
    report.pairedProtocolInvariant = pairInvariant;
    report.commonWorkloadInvariant = workloadInvariant;
    report.hsbpNoDTInvariant = dtOnlyInvariant;
    report.studyReady = fieldsPresent && successful && pairInvariant && ...
        workloadInvariant && dtOnlyInvariant;

    fprintf('============================================\n');
    fprintf('Comparative Stochastic Study Test\n');
    fprintf('============================================\n');
    fprintf('Swarm sizes                 : %s\n', mat2str(swarmSizes));
    fprintf('Repetitions                 : %d\n', repetitions);
    fprintf('Expected results            : %d\n', report.expectedResults);
    fprintf('Actual results              : %d\n', report.totalResults);
    fprintf('Required fields             : %d\n', fieldsPresent);
    fprintf('All runs successful         : %d\n', successful);
    fprintf('Paired protocol invariant   : %d\n', pairInvariant);
    fprintf('Common workload invariant   : %d\n', workloadInvariant);
    fprintf('HSBP no-DT invariant        : %d\n', dtOnlyInvariant);
    fprintf('Study ready                 : %d\n', report.studyReady);
    fprintf('\n');

    if ~report.studyReady
        error('ComparativeStochasticStudyTest:Failed', ...
            'Comparative stochastic study methodology validation failed.');
    end

    fprintf('Comparative stochastic study methodology: PASS\n');
    fprintf('============================================\n');
end
