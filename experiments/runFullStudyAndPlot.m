function study = runFullStudyAndPlot()
%RUNFULLSTUDYANDPLOT Stage E: Full Join/Leave Study across 5 swarm sizes
% and generation of publication-quality figures.

    rootDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(rootDir));

    swarmSizes = [1000 2000 3000 4000 5000];
    repetitions = 3;
    baseSeed = 42;

    fprintf('====================================================\n');
    fprintf('STAGE E: FULL JOIN/LEAVE STUDY (5 SWARM SIZES)\n');
    fprintf('Swarm Sizes : %s\n', mat2str(swarmSizes));
    fprintf('Repetitions : %d\n', repetitions);
    fprintf('Base Seed   : %d\n', baseSeed);
    fprintf('====================================================\n');

    startTime = tic;
    study = runStochasticJoinLeaveStudy(swarmSizes, repetitions, baseSeed);
    elapsedTime = toc(startTime);

    fprintf('\nStudy completed in %.2f minutes (%.1f seconds).\n', ...
        elapsedTime / 60, elapsedTime);

    % Save results mat file
    matPath = fullfile(rootDir, 'experiments', 'full_join_leave_study_results.mat');
    save(matPath, 'study');
    fprintf('Saved study results to: %s\n', matPath);

    % Create figures directory
    figDir = fullfile(rootDir, 'figures');
    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end

    % Also save to artifacts directory
    artifactDir = 'C:\Users\Owner\.gemini\antigravity-ide\brain\08e7439a-0e8c-4e8c-9a76-e0adbb1f8f8f';
    if ~exist(artifactDir, 'dir')
        artifactDir = figDir;
    end

    fprintf('\nGenerating publication-quality figures...\n');
    plotAndExportFigures(study, figDir, artifactDir);

    fprintf('\n====================================================\n');
    fprintf('STAGE E & F COMPLETED SUCCESSFULLY!\n');
    fprintf('====================================================\n');
end

function plotAndExportFigures(study, figDir, artifactDir)
    stats = study.statistics;
    protocols = ["FlatSBP", "HSBP", "DTHSBP"];
    swarmSizes = study.swarmSizes;

    colors = containers.Map();
    colors('FlatSBP') = [0.12 0.47 0.71]; % Blue
    colors('HSBP')    = [0.85 0.33 0.10]; % Red-Orange
    colors('DTHSBP')  = [0.18 0.62 0.18]; % Green

    markers = containers.Map();
    markers('FlatSBP') = 'o';
    markers('HSBP')    = 's';
    markers('DTHSBP')  = '^';

    %% ----------------------------------------------------
    % 1. Join Event Figures
    % ----------------------------------------------------
    % Join Leader Execution Time
    f1 = figure('Visible','off','Position',[100 100 700 500]);
    hold on;
    for p = 1:numel(protocols)
        s = getMetric(stats, "Join", protocols(p), swarmSizes);
        errorbar(swarmSizes, s.leaderTimeMean * 1000, s.leaderTimeStd * 1000, ...
            '-', 'LineWidth', 1.8, 'Marker', markers(protocols(p)), ...
            'Color', colors(protocols(p)), 'MarkerSize', 8, ...
            'MarkerFaceColor', colors(protocols(p)), 'DisplayName', protocols(p));
    end
    hold off; grid on; box on;
    xlabel('UAV Swarm Size (N)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Leader Execution Time (ms)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Join Event - Leader Execution Time', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northwest', 'FontSize', 11);
    saveFig(f1, 'Join_Leader_Execution_Time', figDir, artifactDir);

    % Join Follower Execution Time
    f2 = figure('Visible','off','Position',[100 100 700 500]);
    hold on;
    for p = 1:numel(protocols)
        s = getMetric(stats, "Join", protocols(p), swarmSizes);
        errorbar(swarmSizes, s.followerTimeMean * 1000, s.followerTimeStd * 1000, ...
            '-', 'LineWidth', 1.8, 'Marker', markers(protocols(p)), ...
            'Color', colors(protocols(p)), 'MarkerSize', 8, ...
            'MarkerFaceColor', colors(protocols(p)), 'DisplayName', protocols(p));
    end
    hold off; grid on; box on;
    xlabel('UAV Swarm Size (N)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Follower Execution Time (ms)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Join Event - Follower Execution Time', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northwest', 'FontSize', 11);
    saveFig(f2, 'Join_Follower_Execution_Time', figDir, artifactDir);

    % Join Message Overhead
    f3 = figure('Visible','off','Position',[100 100 700 500]);
    hold on;
    for p = 1:numel(protocols)
        s = getMetric(stats, "Join", protocols(p), swarmSizes);
        errorbar(swarmSizes, s.bytesMean, s.bytesStd, ...
            '-', 'LineWidth', 1.8, 'Marker', markers(protocols(p)), ...
            'Color', colors(protocols(p)), 'MarkerSize', 8, ...
            'MarkerFaceColor', colors(protocols(p)), 'DisplayName', protocols(p));
    end
    hold off; grid on; box on;
    xlabel('UAV Swarm Size (N)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Message Overhead (Bytes)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Join Event - Communication Overhead', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northwest', 'FontSize', 11);
    saveFig(f3, 'Join_Message_Overhead', figDir, artifactDir);

    %% ----------------------------------------------------
    % 2. Leave Event Figures (Matching Paper Fig. 3)
    % ----------------------------------------------------
    % Leave Leader Execution Time
    f4 = figure('Visible','off','Position',[100 100 700 500]);
    hold on;
    for p = 1:numel(protocols)
        s = getMetric(stats, "Leave", protocols(p), swarmSizes);
        errorbar(swarmSizes, s.leaderTimeMean * 1000, s.leaderTimeStd * 1000, ...
            '-', 'LineWidth', 1.8, 'Marker', markers(protocols(p)), ...
            'Color', colors(protocols(p)), 'MarkerSize', 8, ...
            'MarkerFaceColor', colors(protocols(p)), 'DisplayName', protocols(p));
    end
    hold off; grid on; box on;
    xlabel('UAV Swarm Size (N)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Leader Execution Time (ms)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Leave Event - Leader Execution Time', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northwest', 'FontSize', 11);
    saveFig(f4, 'Leave_Leader_Execution_Time', figDir, artifactDir);

    % Leave Follower Execution Time
    f5 = figure('Visible','off','Position',[100 100 700 500]);
    hold on;
    for p = 1:numel(protocols)
        s = getMetric(stats, "Leave", protocols(p), swarmSizes);
        errorbar(swarmSizes, s.followerTimeMean * 1000, s.followerTimeStd * 1000, ...
            '-', 'LineWidth', 1.8, 'Marker', markers(protocols(p)), ...
            'Color', colors(protocols(p)), 'MarkerSize', 8, ...
            'MarkerFaceColor', colors(protocols(p)), 'DisplayName', protocols(p));
    end
    hold off; grid on; box on;
    xlabel('UAV Swarm Size (N)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Follower Execution Time (ms)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Leave Event - Follower Execution Time', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northwest', 'FontSize', 11);
    saveFig(f5, 'Leave_Follower_Execution_Time', figDir, artifactDir);

    % Leave Message Overhead (KB)
    f6 = figure('Visible','off','Position',[100 100 700 500]);
    hold on;
    for p = 1:numel(protocols)
        s = getMetric(stats, "Leave", protocols(p), swarmSizes);
        errorbar(swarmSizes, s.bytesMean / 1024, s.bytesStd / 1024, ...
            '-', 'LineWidth', 1.8, 'Marker', markers(protocols(p)), ...
            'Color', colors(protocols(p)), 'MarkerSize', 8, ...
            'MarkerFaceColor', colors(protocols(p)), 'DisplayName', protocols(p));
    end
    hold off; grid on; box on;
    xlabel('UAV Swarm Size (N)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Message Overhead (KB)', 'FontSize', 12, 'FontWeight', 'bold');
    title('Leave Event - Message Overhead (KB)', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northwest', 'FontSize', 11);
    saveFig(f6, 'Leave_Message_Overhead', figDir, artifactDir);

    % Leave Rekey Count Comparison
    f7 = figure('Visible','off','Position',[100 100 700 500]);
    hold on;
    for p = 1:numel(protocols)
        s = getMetric(stats, "Leave", protocols(p), swarmSizes);
        errorbar(swarmSizes, s.rekeyMean, s.rekeyStd, ...
            '-', 'LineWidth', 1.8, 'Marker', markers(protocols(p)), ...
            'Color', colors(protocols(p)), 'MarkerSize', 8, ...
            'MarkerFaceColor', colors(protocols(p)), 'DisplayName', protocols(p));
    end
    hold off; grid on; box on;
    xlabel('UAV Swarm Size (N)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Rekeys per Leave Episode', 'FontSize', 12, 'FontWeight', 'bold');
    title('Leave Event - Rekey Activity (Batch vs Reactive)', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'northeast', 'FontSize', 11);
    saveFig(f7, 'Leave_Rekey_Activity', figDir, artifactDir);

    % Communication Performance Gain of DT-HSBP (%)
    f8 = figure('Visible','off','Position',[100 100 700 500]);
    sDT = getMetric(stats, "Leave", "DTHSBP", swarmSizes);
    sHSBP = getMetric(stats, "Leave", "HSBP", swarmSizes);
    sFlat = getMetric(stats, "Leave", "FlatSBP", swarmSizes);

    gainOverFlat = ((sFlat.messageMean - sDT.messageMean) ./ sFlat.messageMean) * 100;
    gainOverHSBP = ((sHSBP.messageMean - sDT.messageMean) ./ sHSBP.messageMean) * 100;

    plot(swarmSizes, gainOverFlat, '-o', 'LineWidth', 2.0, 'Color', [0.12 0.47 0.71], ...
        'MarkerSize', 8, 'MarkerFaceColor', [0.12 0.47 0.71], ...
        'DisplayName', 'DT-HSBP Gain vs Flat-SBP');
    hold on;
    plot(swarmSizes, gainOverHSBP, '-s', 'LineWidth', 2.0, 'Color', [0.85 0.33 0.10], ...
        'MarkerSize', 8, 'MarkerFaceColor', [0.85 0.33 0.10], ...
        'DisplayName', 'DT-HSBP Gain vs HSBP');
    hold off; grid on; box on;
    ylim([0 100]);
    xlabel('UAV Swarm Size (N)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Communication Reduction Gain (%)', 'FontSize', 12, 'FontWeight', 'bold');
    title('DT-HSBP Communication Performance Gain', 'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'east', 'FontSize', 11);
    saveFig(f8, 'Communication_Performance_Gain', figDir, artifactDir);

    close all;
end

function s = getMetric(stats, eventType, protocol, swarmSizes)
    nSizes = numel(swarmSizes);
    s.leaderTimeMean = zeros(1, nSizes);
    s.leaderTimeStd  = zeros(1, nSizes);
    s.followerTimeMean = zeros(1, nSizes);
    s.followerTimeStd  = zeros(1, nSizes);
    s.messageMean    = zeros(1, nSizes);
    s.messageStd     = zeros(1, nSizes);
    s.bytesMean      = zeros(1, nSizes);
    s.bytesStd       = zeros(1, nSizes);
    s.rekeyMean      = zeros(1, nSizes);
    s.rekeyStd       = zeros(1, nSizes);

    for i = 1:nSizes
        idx = find(string({stats.eventType}) == eventType & ...
                   string({stats.protocol}) == protocol & ...
                   [stats.swarmSize] == swarmSizes(i));
        if isempty(idx), continue; end
        row = stats(idx);
        s.leaderTimeMean(i) = row.leaderTimeMean;
        s.leaderTimeStd(i)  = row.leaderTimeStd;
        s.followerTimeMean(i) = row.followerTimeMean;
        s.followerTimeStd(i)  = row.followerTimeStd;
        s.messageMean(i)    = row.messageMean;
        s.messageStd(i)     = row.messageStd;
        s.bytesMean(i)      = row.bytesMean;
        s.bytesStd(i)       = row.bytesStd;
        s.rekeyMean(i)      = row.rekeyMean;
        s.rekeyStd(i)       = row.rekeyStd;
    end
end

function saveFig(figHandle, figName, figDir, artifactDir)
    pngPath1 = fullfile(figDir, [figName '.png']);
    saveas(figHandle, pngPath1);
    fprintf('  Saved figure: %s\n', pngPath1);

    if ~strcmp(figDir, artifactDir)
        pngPath2 = fullfile(artifactDir, [figName '.png']);
        copyfile(pngPath1, pngPath2);
        fprintf('  Exported to artifact: %s\n', pngPath2);
    end
end
