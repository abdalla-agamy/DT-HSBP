function figures = plotExperimentFigures(report,eventType)
%PLOTEXPERIMENTFIGURES Plot repeated-study experiment measurements.
%
%   FIGURES = PLOTEXPERIMENTFIGURES(REPORT,EVENTTYPE) creates three
%   figures for the supplied ExperimentReport table:
%       1. leader execution time
%       2. follower execution time
%       3. message overhead
%
%   Execution times are converted from seconds to milliseconds. Message
%   overhead is shown in bytes for Join events and KB for Leave events,
%   matching the units used by the corresponding paper figures.
%
%   The plots represent the protocols currently implemented in MATLAB.
%   They are therefore implementation measurements and are not claimed to
%   reproduce the paper's CORE measurements exactly.

    if nargin < 2
        error('plotExperimentFigures:InvalidArguments', ...
            'report and eventType are required.');
    end

    if ~istable(report)
        error('plotExperimentFigures:InvalidReport', ...
            'report must be a MATLAB table produced by ExperimentReport.toTable.');
    end

    eventType = string(eventType);
    if eventType ~= "Join" && eventType ~= "Leave"
        error('plotExperimentFigures:InvalidEventType', ...
            'eventType must be "Join" or "Leave".');
    end

    requiredVariables = { ...
        'Protocol', 'SwarmSize', ...
        'LeaderTimeMean', 'LeaderTimeStd', ...
        'FollowerTimeMean', 'FollowerTimeStd', ...
        'MessageBytesMean', 'MessageBytesStd'};

    for i = 1:numel(requiredVariables)
        if ~ismember(requiredVariables{i},report.Properties.VariableNames)
            error('plotExperimentFigures:MissingVariable', ...
                'Missing report variable: %s',requiredVariables{i});
        end
    end

    protocols = string(report.Protocol);
    swarmSizes = unique(report.SwarmSize,'sorted');
    protocolNames = unique(protocols,'stable');

    figures = gobjects(3,1);

    %% Leader execution time
    figures(1) = figure('Name',eventType + " - Leader Execution Time");
    hold on;

    for p = 1:numel(protocolNames)
        mask = protocols == protocolNames(p);
        [x,order] = sort(report.SwarmSize(mask));
        y = report.LeaderTimeMean(mask);
        e = report.LeaderTimeStd(mask);
        y = y(order) * 1000;
        e = e(order) * 1000;
        errorbar(x,y,e,'-o','DisplayName',protocolNames(p));
    end

    hold off;
    grid on;
    xlabel('UAV Swarm Size (N)');
    ylabel('Time (ms)');
    title(eventType + " Event - Leader Execution Time");
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);

    %% Follower execution time
    figures(2) = figure('Name',eventType + " - Follower Execution Time");
    hold on;

    for p = 1:numel(protocolNames)
        mask = protocols == protocolNames(p);
        [x,order] = sort(report.SwarmSize(mask));
        y = report.FollowerTimeMean(mask);
        e = report.FollowerTimeStd(mask);
        y = y(order) * 1000;
        e = e(order) * 1000;
        errorbar(x,y,e,'-o','DisplayName',protocolNames(p));
    end

    hold off;
    grid on;
    xlabel('UAV Swarm Size (N)');
    ylabel('Time (ms)');
    title(eventType + " Event - Follower Execution Time");
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);

    %% Message overhead
    figures(3) = figure('Name',eventType + " - Message Overhead");
    hold on;

    for p = 1:numel(protocolNames)
        mask = protocols == protocolNames(p);
        [x,order] = sort(report.SwarmSize(mask));
        y = report.MessageBytesMean(mask);
        e = report.MessageBytesStd(mask);

        if eventType == "Leave"
            y = y / 1024;
            e = e / 1024;
        end

        y = y(order);
        e = e(order);
        errorbar(x,y,e,'-o','DisplayName',protocolNames(p));
    end

    hold off;
    grid on;
    xlabel('UAV Swarm Size (N)');

    if eventType == "Leave"
        ylabel('Overhead (KB)');
    else
        ylabel('Overhead (Bytes)');
    end

    title(eventType + " Event - Message Overhead");
    legend('Location','best');
    xlim([min(swarmSizes) max(swarmSizes)]);

end

%% ======================================================================
% PREDICTION ACCURACY SENSITIVITY PLOT (ETA SWEEP)
% ======================================================================
function f = plotPredictionAccuracySensitivity(etaData, figDir, artifactDir)
%PLOTPREDICTIONACCURACYSENSITIVITY Plot Communication Overhead vs Prediction Accuracy (\eta)
    if nargin < 2 || isempty(figDir)
        figDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'figures');
    end
    if nargin < 3 || isempty(artifactDir)
        artifactDir = figDir;
    end
    if ~exist(figDir, 'dir'), mkdir(figDir); end

    f = figure('Visible', 'off', 'Position', [100 100 800 500]);
    
    eta = etaData.eta;
    dtBytes = etaData.dtHsbpBytes;
    hsbpBytes = etaData.hsbpBytes;
    lkhBytes = etaData.lkhBytes;
    
    % Colors
    cDt = [0.18 0.62 0.18];
    cHsbp = [0.85 0.33 0.10];
    cLkh = [0.20 0.40 0.70];
    
    plot(eta, dtBytes, '-^', 'Color', cDt, 'LineWidth', 2.2, 'MarkerSize', 8, 'MarkerFaceColor', cDt); hold on;
    plot(eta, hsbpBytes, '--s', 'Color', cHsbp, 'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', cHsbp);
    plot(eta, lkhBytes, '-.d', 'Color', cLkh, 'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', cLkh);
    
    % Highlight default baseline eta = 0.85
    xline(0.85, ':k', 'Baseline \eta = 0.85', 'LineWidth', 1.5, ...
        'LabelVerticalAlignment', 'bottom', 'LabelHorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold');
    
    grid on; box on;
    xlabel('DT Prediction Accuracy (\eta)', 'FontWeight', 'bold');
    ylabel('Communication Overhead (Bytes)', 'FontWeight', 'bold');
    title('Communication Overhead vs. Prediction Accuracy (\eta)', 'FontWeight', 'bold');
    legend('DT-HSBP (Lifespan-Sorted)', 'Baseline HSBP (Unsorted Cascade)', 'LKH (Tree d=3)', ...
        'Location', 'northeast');
    xlim([min(eta) max(eta)]);
    ylim([0 max([max(hsbpBytes), max(dtBytes), max(lkhBytes)]) * 1.15]);
    
    pngPath1 = fullfile(figDir, 'Prediction_Accuracy_Sensitivity_Eta.png');
    try
        exportgraphics(f, pngPath1, 'Resolution', 300);
    catch
        saveas(f, pngPath1);
    end
    fprintf('  Saved Figure: %s\n', pngPath1);

    if ~strcmp(figDir, artifactDir) && exist(artifactDir, 'dir')
        pngPath2 = fullfile(artifactDir, 'Prediction_Accuracy_Sensitivity_Eta.png');
        try
            copyfile(pngPath1, pngPath2);
            fprintf('  Exported to Artifact: %s\n', pngPath2);
        catch
        end
    end
    close(f);
end

%% ======================================================================
% BATCH-DEPARTURE SCALABILITY PLOT (M SIMULTANEOUS DEPARTURES)
% ======================================================================
function f = plotBatchDepartureScalability(batchData, figDir, artifactDir)
%PLOTBATCHDEPARTURESCALABILITY Dual-subplot: Overhead vs M, Leader Time vs M
    if nargin < 2 || isempty(figDir)
        figDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'figures');
    end
    if nargin < 3 || isempty(artifactDir)
        artifactDir = figDir;
    end
    if ~exist(figDir, 'dir'), mkdir(figDir); end

    f = figure('Visible', 'off', 'Position', [100 100 1000 450]);
    M = batchData.M;

    cDt = [0.18 0.62 0.18];
    cHsbp = [0.85 0.33 0.10];
    cLkh = [0.20 0.40 0.70];

    % Subplot 1: Broadcast Communication Overhead vs M (KB)
    subplot(1, 2, 1);
    plot(M, batchData.DT_HSBP.bytes / 1024, '-^', 'Color', cDt, 'LineWidth', 2.2, 'MarkerSize', 8, 'MarkerFaceColor', cDt); hold on;
    plot(M, batchData.HSBP.bytes / 1024, '--s', 'Color', cHsbp, 'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', cHsbp);
    plot(M, batchData.LKH.bytes / 1024, '-.d', 'Color', cLkh, 'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', cLkh);
    grid on; box on;
    xlabel('Concurrent Departing Drones (M)', 'FontWeight', 'bold');
    ylabel('Communication Overhead (KB)', 'FontWeight', 'bold');
    title('(a) Batch Departure Communication Overhead', 'FontWeight', 'bold');
    legend('DT-HSBP (Flat O(1) Broadcast)', 'Baseline HSBP (Cascade O(M \cdot n_c))', 'LKH (Tree Multi-Path)', 'Location', 'northwest');
    xlim([min(M) max(M)]);

    % Subplot 2: Leader Computation Time vs M (ms)
    subplot(1, 2, 2);
    plot(M, batchData.DT_HSBP.leaderMs, '-^', 'Color', cDt, 'LineWidth', 2.2, 'MarkerSize', 8, 'MarkerFaceColor', cDt); hold on;
    plot(M, batchData.HSBP.leaderMs, '--s', 'Color', cHsbp, 'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', cHsbp);
    plot(M, batchData.LKH.leaderMs, '-.d', 'Color', cLkh, 'LineWidth', 2.0, 'MarkerSize', 8, 'MarkerFaceColor', cLkh);
    grid on; box on;
    xlabel('Concurrent Departing Drones (M)', 'FontWeight', 'bold');
    ylabel('Leader Computation Time (ms)', 'FontWeight', 'bold');
    title('(b) Leader Computation Time vs. Batch Size M', 'FontWeight', 'bold');
    legend('DT-HSBP (Flat O(1) Prefix Cache)', 'Baseline HSBP (Sequential Cascade)', 'LKH (Symmetric Tree Encs)', 'Location', 'northwest');
    xlim([min(M) max(M)]);

    pngPath1 = fullfile(figDir, 'Batch_Departure_Scalability.png');
    try
        exportgraphics(f, pngPath1, 'Resolution', 300);
    catch
        saveas(f, pngPath1);
    end
    fprintf('  Saved Figure: %s\n', pngPath1);

    if ~strcmp(figDir, artifactDir) && exist(artifactDir, 'dir')
        pngPath2 = fullfile(artifactDir, 'Batch_Departure_Scalability.png');
        try
            copyfile(pngPath1, pngPath2);
            fprintf('  Exported to Artifact: %s\n', pngPath2);
        catch
        end
    end
    close(f);
end
