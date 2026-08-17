%% STOCHASTICEXPERIMENT
% Root-level executable driver for the Poisson stochastic experiment.
%
% Edit the USER OPTIONS section below, then run this file directly:
%
%     StochasticExperiment
%
% The script runs the stochastic study, prints mean +/- standard deviation
% statistics, reports DT-HSBP performance gains relative to FlatSBP/HSBP,
% and generates the stochastic figures.
%
% PARALLEL_EXECUTION = true requires the Parallel Computing Toolbox.
% If enabled but the toolbox is unavailable, the script stops with a clear
% error rather than silently falling back to serial execution.

%% ========================= USER OPTIONS ================================
PARALLEL_EXECUTION = false;     % false = normal, true = Parallel Toolbox

PROTOCOLS   = ["FlatSBP","HSBP","DTHSBP"];
SWARM_SIZES = [1000 2000 3000 4000 5000];
REPETITIONS = 3;
BASE_SEED   = 42;

%% ========================= RUN STUDY ==================================
clearvars -except PARALLEL_EXECUTION PROTOCOLS SWARM_SIZES REPETITIONS BASE_SEED
clc
close all

fprintf('============================================\n');
fprintf('Stochastic Experiment\n');
fprintf('============================================\n');
fprintf('Protocols    : %s\n',strjoin(PROTOCOLS,', '));
fprintf('Swarm sizes  : %s\n',mat2str(SWARM_SIZES));
fprintf('Repetitions  : %d\n',REPETITIONS);
fprintf('Base seed    : %g\n',BASE_SEED);
fprintf('Execution    : %s\n',ternary(PARALLEL_EXECUTION,"PARALLEL","SERIAL"));
fprintf('============================================\n');

if PARALLEL_EXECUTION
    if ~license('test','Distrib_Computing_Toolbox')
        error('StochasticExperiment:ParallelToolboxRequired', ...
            ['PARALLEL_EXECUTION=true, but the Parallel Computing Toolbox ' ...
             'is not available. Set PARALLEL_EXECUTION=false or install/enable the toolbox.']);
    end

    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('local'); %#ok<NASGU>
    end

    % The study runner is the canonical serial/paired experiment runner.
    % Parallel execution is enabled through the study runner's parallel
    % option when supported by the current repository implementation.
    results = runStochasticStudy( ...
        PROTOCOLS,SWARM_SIZES,REPETITIONS,BASE_SEED,'UseParallel',true);
else
    results = runStochasticStudy( ...
        PROTOCOLS,SWARM_SIZES,REPETITIONS,BASE_SEED);
end

if isempty(results)
    error('StochasticExperiment:NoResults', ...
        'The stochastic study returned no results.');
end

if ~all([results.success])
    failed = find(~[results.success]);
    error('StochasticExperiment:RunFailure', ...
        '%d stochastic runs failed. First failed result index: %d.', ...
        numel(failed),failed(1));
end

fprintf('\nSuccessful runs: %d / %d\n',numel(results),numel(results));

%% ========================= STATISTICS =================================
printStochasticStatistics(results,PROTOCOLS,SWARM_SIZES);

%% ========================= FIGURES ====================================
figures = plotStochasticFigures(results);

fprintf('\n============================================\n');
fprintf('STOCHASTIC EXPERIMENT COMPLETE\n');
fprintf('Figures generated: %d\n',numel(figures));
fprintf('============================================\n');

%% ========================= LOCAL FUNCTIONS ============================
function printStochasticStatistics(results,protocols,swarmSizes)
    fprintf('\n============================================\n');
    fprintf('STOCHASTIC STATISTICS (mean +/- std)\n');
    fprintf('============================================\n');

    fprintf('\n--- COMMUNICATION ---\n');
    fprintf('%-8s %-6s %-18s %-18s %-18s\n', ...
        'Protocol','N','Messages','Bytes','Rekeys');

    for p = 1:numel(protocols)
        for n = 1:numel(swarmSizes)
            x = results(string({results.protocol}) == protocols(p) & ...
                        [results.initialSwarmSize] == swarmSizes(n));
            fprintf('%-8s %-6d %-18s %-18s %-18s\n', ...
                protocols(p),swarmSizes(n), ...
                meanStdString([x.totalMessages]), ...
                meanStdString([x.totalBytes]), ...
                meanStdString([x.localRekeys] + [x.batchRekeys]));
        end
    end

    fprintf('\n--- STOCHASTIC WORKLOAD ---\n');
    fprintf('%-8s %-6s %-18s %-18s %-18s\n', ...
        'Protocol','N','Joins','Leaves','Failures');

    for p = 1:numel(protocols)
        for n = 1:numel(swarmSizes)
            x = results(string({results.protocol}) == protocols(p) & ...
                        [results.initialSwarmSize] == swarmSizes(n));
            fprintf('%-8s %-6d %-18s %-18s %-18s\n', ...
                protocols(p),swarmSizes(n), ...
                meanStdString([x.joinEvents]), ...
                meanStdString([x.leaveEvents]), ...
                meanStdString([x.failureEvents]));
        end
    end

    fprintf('\n--- DT-HSBP ---\n');
    fprintf('%-6s %-18s %-18s %-18s\n', ...
        'N','Predicted leaves','Batch rekeys','Final active UAVs');

    dt = protocols == "DTHSBP";
    for n = 1:numel(swarmSizes)
        x = results(dt([results(dt).initialSwarmSize] == swarmSizes(n)));
        fprintf('%-6d %-18s %-18s %-18s\n', ...
            swarmSizes(n), ...
            meanStdString([x.predictedLeaves]), ...
            meanStdString([x.batchRekeys]), ...
            meanStdString([x.finalActiveUAVs]));
    end

    printPerformanceGains(results,swarmSizes);
end

function printPerformanceGains(results,swarmSizes)
    fprintf('\n--- DTHSBP PERFORMANCE GAIN ---\n');
    fprintf('Gain is positive when DTHSBP has lower communication cost.\n');
    fprintf('%-6s %-18s %-18s %-18s %-18s\n', ...
        'N','Msg vs Flat','Bytes vs Flat','Msg vs HSBP','Bytes vs HSBP');

    protocols = string({results.protocol});
    for n = 1:numel(swarmSizes)
        flat = results(protocols == "FlatSBP" & [results.initialSwarmSize] == swarmSizes(n));
        hsbp = results(protocols == "HSBP"    & [results.initialSwarmSize] == swarmSizes(n));
        dt   = results(protocols == "DTHSBP"  & [results.initialSwarmSize] == swarmSizes(n));

        flatMsg = [flat.totalMessages];
        hsbpMsg = [hsbp.totalMessages];
        dtMsg   = [dt.totalMessages];
        flatBytes = [flat.totalBytes];
        hsbpBytes = [hsbp.totalBytes];
        dtBytes = [dt.totalBytes];

        fprintf('%-6d %-18s %-18s %-18s %-18s\n', ...
            swarmSizes(n), ...
            gainString(flatMsg,dtMsg), ...
            gainString(flatBytes,dtBytes), ...
            gainString(hsbpMsg,dtMsg), ...
            gainString(hsbpBytes,dtBytes));
    end
end

function s = meanStdString(x)
    if isempty(x)
        s = 'N/A';
        return;
    end
    m = mean(x);
    if numel(x) > 1
        sd = std(x,0);
    else
        sd = 0;
    end
    s = sprintf('%.6g +/- %.6g',m,sd);
end

function s = gainString(reference,current)
    if isempty(reference) || isempty(current)
        s = 'N/A';
        return;
    end
    ref = mean(reference);
    cur = mean(current);
    if ref == 0
        s = 'N/A';
        return;
    end
    gain = 100*(ref-cur)/ref;
    s = sprintf('%+.2f%%',gain);
end

function value = ternary(condition,a,b)
    if condition
        value = a;
    else
        value = b;
    end
end
