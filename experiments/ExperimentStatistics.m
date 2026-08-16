classdef ExperimentStatistics
    %EXPERIMENTSTATISTICS Statistical aggregation of experiment observations.
    %
    % Computes descriptive statistics independently for each
    % (protocol, swarmSize) configuration.

    methods (Static)

        function statistics = summarize(results)
            %SUMMARIZE Aggregate raw ExperimentResult structs.
            %
            % STATISTICS = SUMMARIZE(RESULTS) returns one row per unique
            % protocol/swarm-size configuration. For each measured metric,
            % mean, sample variance, and sample standard deviation are
            % reported.

            if isempty(results)
                statistics = struct([]);
                return;
            end

            if ~isstruct(results)
                error('ExperimentStatistics:InvalidInput', ...
                    'results must be a struct array.');
            end

            requiredFields = { ...
                'protocol', 'swarmSize', ...
                'leaderTime', 'followerTime', ...
                'messageCount', 'messageBytes'};

            for i = 1:numel(requiredFields)
                if ~isfield(results, requiredFields{i})
                    error('ExperimentStatistics:MissingField', ...
                        'Missing required result field: %s', ...
                        requiredFields{i});
                end
            end

            protocols = string({results.protocol});
            swarmSizes = [results.swarmSize];

            keys = unique([protocols + "|" + string(swarmSizes)], 'stable');
            statistics = repmat(ExperimentStatistics.emptyRecord(), ...
                numel(keys), 1);

            for k = 1:numel(keys)
                parts = split(keys(k), '|');
                protocol = parts(1);
                swarmSize = str2double(parts(2));

                mask = protocols == protocol & swarmSizes == swarmSize;
                observations = results(mask);

                statistics(k).protocol = protocol;
                statistics(k).swarmSize = swarmSize;
                statistics(k).sampleCount = numel(observations);

                statistics(k).leaderTime = ...
                    ExperimentStatistics.describe([observations.leaderTime]);
                statistics(k).followerTime = ...
                    ExperimentStatistics.describe([observations.followerTime]);
                statistics(k).messageCount = ...
                    ExperimentStatistics.describe([observations.messageCount]);
                statistics(k).messageBytes = ...
                    ExperimentStatistics.describe([observations.messageBytes]);
            end
        end

    end

    methods (Static, Access = private)

        function record = emptyRecord()
            record = struct( ...
                'protocol', "", ...
                'swarmSize', 0, ...
                'sampleCount', 0, ...
                'leaderTime', struct('mean',0,'variance',0,'std',0), ...
                'followerTime', struct('mean',0,'variance',0,'std',0), ...
                'messageCount', struct('mean',0,'variance',0,'std',0), ...
                'messageBytes', struct('mean',0,'variance',0,'std',0));
        end

        function statistics = describe(values)
            values = double(values(:));
            n = numel(values);

            statistics.mean = mean(values);

            if n > 1
                statistics.variance = var(values, 0);
                statistics.std = std(values, 0);
            else
                statistics.variance = NaN;
                statistics.std = NaN;
            end
        end

    end
end
