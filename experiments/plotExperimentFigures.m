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
