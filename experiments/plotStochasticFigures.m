function figures = plotStochasticFigures(results)
%PLOTSTOCHASTICFIGURES Plot Poisson-driven stochastic experiment results.
%
%   FIGURES = PLOTSTOCHASTICFIGURES(RESULTS) creates figures from the
%   independent stochastic experiment results returned by
%   runStochasticStudy.
%
%   The figures are intended for both smoke-test visualization and the
%   final stochastic study. When multiple repetitions are available, the
%   plots show mean +/- one standard deviation across repetitions for each
%   protocol and initial swarm size.
%
%   The controlled Join/Leave timing figures are intentionally handled by
%   plotExperimentFigures.m and are not mixed with these stochastic plots.

    if nargin ~= 1
        error('plotStochasticFigures:InvalidArguments', ...
            'Provide the stochastic result array.');
    end

    if ~isstruct(results) || isempty(results)
        error('plotStochasticFigures:InvalidResults', ...
            'results must be a non-empty struct array from runStochasticStudy.');
    end

    required = { ...
        'protocol', 'initialSwarmSize', 'runID', 'success', ...
        'joinEvents', 'leaveEvents', 'failureEvents', ...
        'predictedLeaves', 'localRekeys', 'batchRekeys', ...
        'totalMessages', 'totalBytes', 'finalActiveUAVs'};

    for i = 1:numel(required)
        if ~isfield(results, required{i})
            error('plotStochasticFigures:MissingField', ...
                'Missing required result field: %s', required{i});
        end
    end

    if any(~[results.success])
        error('plotStochasticFigures:UnsuccessfulResults', ...
            'All supplied stochastic runs must be successful.');
    end

    protocols = ["FlatSBP", "HSBP", "DTHSBP"];
    swarmSizes = unique([results.initialSwarmSize], 'sorted');

    figures = gobjects(6,1);

    %% 1. Final active UAVs
    figures(1) = figure('Name','Stochastic - Final Active UAVs');
    hold on;
    for p = 1:numel(protocols)
        [x, y, e] = aggregateMetric(results, protocols(p), swarmSizes, ...
            @(r) r.finalActiveUAVs);
        errorbar(x, y, e, '-o', 'DisplayName', protocols(p));
    end
    hold off;
    grid on;
    xlabel('Initial UAV Swarm Size (N)');
    ylabel('Final Active UAVs');
    title('Stochastic Simulation - Final Active Population');
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);

    %% 2. Event workload
    figures(2) = figure('Name','Stochastic - Event Workload');
    hold on;
    eventNames = {'Join','Leave','Failure'};
    eventFields = {@(r) r.joinEvents, @(r) r.leaveEvents, @(r) r.failureEvents};
    % Show the workload means aggregated across protocols so the plot
    % represents the common stochastic realization rather than protocol cost.
    for eidx = 1:numel(eventNames)
        [x, y, e] = aggregateAcrossProtocols(results, swarmSizes, eventFields{eidx});
        errorbar(x, y, e, '-o', 'DisplayName', eventNames{eidx});
    end
    hold off;
    grid on;
    xlabel('Initial UAV Swarm Size (N)');
    ylabel('Events per 100-simulation-unit run');
    title('Stochastic Simulation - Event Workload');
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);

    %% 3. Total messages
    figures(3) = figure('Name','Stochastic - Total Messages');
    hold on;
    for p = 1:numel(protocols)
        [x, y, e] = aggregateMetric(results, protocols(p), swarmSizes, ...
            @(r) r.totalMessages);
        errorbar(x, y, e, '-o', 'DisplayName', protocols(p));
    end
    hold off;
    grid on;
    xlabel('Initial UAV Swarm Size (N)');
    ylabel('Total Messages');
    title('Stochastic Simulation - Total Message Count');
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);

    %% 4. Communication bytes
    figures(4) = figure('Name','Stochastic - Communication Bytes');
    hold on;
    for p = 1:numel(protocols)
        [x, y, e] = aggregateMetric(results, protocols(p), swarmSizes, ...
            @(r) r.totalBytes);
        errorbar(x, y / 1024, e / 1024, '-o', 'DisplayName', protocols(p));
    end
    hold off;
    grid on;
    xlabel('Initial UAV Swarm Size (N)');
    ylabel('Total Communication (KB)');
    title('Stochastic Simulation - Communication Overhead');
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);

    %% 5. Rekey activity
    figures(5) = figure('Name','Stochastic - Rekey Activity');
    hold on;
    for p = 1:numel(protocols)
        [x, localMean, localStd] = aggregateMetric(results, protocols(p), swarmSizes, ...
            @(r) r.localRekeys);
        [~, batchMean, batchStd] = aggregateMetric(results, protocols(p), swarmSizes, ...
            @(r) r.batchRekeys);

        totalMean = localMean + batchMean;
        totalStd = sqrt(localStd.^2 + batchStd.^2);
        errorbar(x, totalMean, totalStd, '-o', 'DisplayName', protocols(p));
    end
    hold off;
    grid on;
    xlabel('Initial UAV Swarm Size (N)');
    ylabel('Total Rekeys');
    title('Stochastic Simulation - Rekey Activity');
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);

    %% 6. DT prediction / batch rekey activity
    figures(6) = figure('Name','Stochastic - DT Prediction and Batch Rekeys');
    hold on;
    dtResults = results(string({results.protocol}) == "DTHSBP");
    [x, predictedMean, predictedStd] = aggregateMetric(dtResults, "DTHSBP", swarmSizes, ...
        @(r) r.predictedLeaves);
    errorbar(x, predictedMean, predictedStd, '-o', ...
        'DisplayName','Predicted Leaves');

    [~, batchMean, batchStd] = aggregateMetric(dtResults, "DTHSBP", swarmSizes, ...
        @(r) r.batchRekeys);
    errorbar(x, batchMean, batchStd, '-s', ...
        'DisplayName','Batch Rekeys');
    hold off;
    grid on;
    xlabel('Initial UAV Swarm Size (N)');
    ylabel('Count per Run');
    title('DT-HSBP Stochastic Simulation - Prediction and Batch Rekey');
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);
end

function [x, meanValues, stdValues] = aggregateMetric(results, protocol, swarmSizes, getter)
    protocolValues = string({results.protocol});
    maskProtocol = protocolValues == protocol;

    x = swarmSizes(:);
    meanValues = zeros(size(x));
    stdValues = zeros(size(x));

    for i = 1:numel(swarmSizes)
        mask = maskProtocol & [results.initialSwarmSize] == swarmSizes(i);
        group = results(mask);

        if isempty(group)
            error('plotStochasticFigures:MissingGroup', ...
                'Missing results for %s at N=%d.', protocol, swarmSizes(i));
        end

        values = zeros(1, numel(group));
        for k = 1:numel(group)
            values(k) = getter(group(k));
        end

        meanValues(i) = mean(values);
        stdValues(i) = std(values, 0, 2);
    end
end

function [x, meanValues, stdValues] = aggregateAcrossProtocols(results, swarmSizes, getter)
    protocols = unique(string({results.protocol}), 'stable');
    x = swarmSizes(:);
    meanValues = zeros(size(x));
    stdValues = zeros(size(x));

    for i = 1:numel(swarmSizes)
        values = [];

        for p = 1:numel(protocols)
            mask = string({results.protocol}) == protocols(p) & ...
                [results.initialSwarmSize] == swarmSizes(i);
            group = results(mask);

            for k = 1:numel(group)
                values(end+1) = getter(group(k)); %#ok<AGROW>
            end
        end

        meanValues(i) = mean(values);
        stdValues(i) = std(values, 0, 2);
    end
end
