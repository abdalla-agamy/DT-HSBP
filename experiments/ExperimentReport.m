classdef ExperimentReport
    %EXPERIMENTREPORT Convert experiment statistics into report tables.

    methods (Static)

        function report = toTable(statistics)
            %TOTABLE Convert aggregated statistics to a MATLAB table.

            if isempty(statistics)
                report = table();
                return;
            end

            n = numel(statistics);

            protocol = strings(n,1);
            swarmSize = zeros(n,1);
            sampleCount = zeros(n,1);

            leaderMean = zeros(n,1);
            leaderVariance = NaN(n,1);
            leaderStd = NaN(n,1);

            followerMean = zeros(n,1);
            followerVariance = NaN(n,1);
            followerStd = NaN(n,1);

            messageMean = zeros(n,1);
            messageVariance = NaN(n,1);
            messageStd = NaN(n,1);

            bytesMean = zeros(n,1);
            bytesVariance = NaN(n,1);
            bytesStd = NaN(n,1);

            for i = 1:n
                protocol(i) = string(statistics(i).protocol);
                swarmSize(i) = statistics(i).swarmSize;
                sampleCount(i) = statistics(i).sampleCount;

                leaderMean(i) = statistics(i).leaderTime.mean;
                leaderVariance(i) = statistics(i).leaderTime.variance;
                leaderStd(i) = statistics(i).leaderTime.std;

                followerMean(i) = statistics(i).followerTime.mean;
                followerVariance(i) = statistics(i).followerTime.variance;
                followerStd(i) = statistics(i).followerTime.std;

                messageMean(i) = statistics(i).messageCount.mean;
                messageVariance(i) = statistics(i).messageCount.variance;
                messageStd(i) = statistics(i).messageCount.std;

                bytesMean(i) = statistics(i).messageBytes.mean;
                bytesVariance(i) = statistics(i).messageBytes.variance;
                bytesStd(i) = statistics(i).messageBytes.std;
            end

            report = table( ...
                protocol, swarmSize, sampleCount, ...
                leaderMean, leaderVariance, leaderStd, ...
                followerMean, followerVariance, followerStd, ...
                messageMean, messageVariance, messageStd, ...
                bytesMean, bytesVariance, bytesStd, ...
                'VariableNames', { ...
                    'Protocol', 'SwarmSize', 'SampleCount', ...
                    'LeaderTimeMean', 'LeaderTimeVariance', 'LeaderTimeStd', ...
                    'FollowerTimeMean', 'FollowerTimeVariance', 'FollowerTimeStd', ...
                    'MessageCountMean', 'MessageCountVariance', 'MessageCountStd', ...
                    'MessageBytesMean', 'MessageBytesVariance', 'MessageBytesStd'});
        end

    end
end
