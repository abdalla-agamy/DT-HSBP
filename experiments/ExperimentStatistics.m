classdef ExperimentStatistics
    %EXPERIMENTSTATISTICS Statistical aggregation of experiment observations.
    %
    % Computes descriptive statistics independently for each
    % (eventType, protocol, swarmSize) configuration.

    methods (Static)

        function statistics = summarize(results)
            %SUMMARIZE Aggregate raw ExperimentResult structs.
            %
            % STATISTICS = SUMMARIZE(RESULTS) returns one row per unique
            % event/protocol/swarm-size configuration. Failed and rejected
            % observations are excluded from performance statistics, while
            % attempted, successful, rejected, and failed counts are kept.

            if isempty(results)
                statistics = struct([]);
                return;
            end

            if ~isstruct(results)
                error('ExperimentStatistics:InvalidInput', ...
                    'results must be a struct array.');
            end

            requiredFields = { ...
                'eventType', 'protocol', 'swarmSize', ...
                'leaderTime', 'followerTime', ...
                'messageCount', 'messageBytes', ...
                'success', 'status'};

            for i = 1:numel(requiredFields)
                if ~isfield(results, requiredFields{i})
                    error('ExperimentStatistics:MissingField', ...
                        'Missing required result field: %s', ...
                        requiredFields{i});
                end
            end

            eventTypes = string({results.eventType});
            protocols = string({results.protocol});
            swarmSizes = [results.swarmSize];

            keys = unique( ...
                eventTypes + "|" + protocols + "|" + string(swarmSizes), ...
                'stable');

            statistics = repmat(ExperimentStatistics.emptyRecord(), ...
                numel(keys), 1);

            for k = 1:numel(keys)
                parts = split(keys(k), '|');

                eventType = parts(1);
                protocol = parts(2);
                swarmSize = str2double(parts(3));

                mask = eventTypes == eventType & ...
                       protocols == protocol & ...
                       swarmSizes == swarmSize;

                observations = results(mask);

                successMask = [observations.success];
                successful = observations(successMask);

                statuses = string({observations.status});

                statistics(k).eventType = eventType;
                statistics(k).protocol = protocol;
                statistics(k).swarmSize = swarmSize;

                statistics(k).attemptedCount = numel(observations);
                statistics(k).successfulCount = numel(successful);
                statistics(k).rejectedCount = sum(statuses == "Rejected");
                statistics(k).failedCount = sum(statuses == "Failed");

                statistics(k).leaderTime = ...
                    ExperimentStatistics.describe([successful.leaderTime]);
                statistics(k).followerTime = ...
                    ExperimentStatistics.describe([successful.followerTime]);
                statistics(k).messageCount = ...
                    ExperimentStatistics.describe([successful.messageCount]);
                statistics(k).messageBytes = ...
                    ExperimentStatistics.describe([successful.messageBytes]);
            end
        end

    end

    methods (Static, Access = private)

        function record = emptyRecord()
            record = struct( ...
                'eventType', "", ...
                'protocol', "", ...
                'swarmSize', 0, ...
                'attemptedCount', 0, ...
                'successfulCount', 0, ...
                'rejectedCount', 0, ...
                'failedCount', 0, ...
                'leaderTime', struct('mean',NaN,'variance',NaN,'std',NaN), ...
                'followerTime', struct('mean',NaN,'variance',NaN,'std',NaN), ...
                'messageCount', struct('mean',NaN,'variance',NaN,'std',NaN), ...
                'messageBytes', struct('mean',NaN,'variance',NaN,'std',NaN));
        end

        function statistics = describe(values)
            values = double(values(:));
            n = numel(values);

            if n == 0
                statistics.mean = NaN;
                statistics.variance = NaN;
                statistics.std = NaN;
                return;
            end

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
