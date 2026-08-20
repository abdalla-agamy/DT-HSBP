function study = runStochasticJoinLeaveStudy(swarmSizes, repetitions, baseSeed)
%RUNSTOCHASTICJOINLEAVESTUDY Paired stochastic Join/Leave performance study.
% Keeps Join and Leave statistics separate and enforces identical event
% counts across FlatSBP, HSBP, and DTHSBP for every paired run.

    if nargin < 1 || isempty(swarmSizes), swarmSizes = [1000 2000 3000 4000 5000]; end
    if nargin < 2 || isempty(repetitions), repetitions = 3; end
    if nargin < 3 || isempty(baseSeed), baseSeed = 42; end

    protocols = ["FlatSBP","HSBP","DTHSBP"];
    eventTypes = ["Join","Leave"];
    swarmSizes = swarmSizes(:).';
    totalRuns = numel(protocols)*numel(swarmSizes)*repetitions*numel(eventTypes);

    template = emptyResult();
    results = repmat(template,totalRuns,1);
    k = 0;

    for e = 1:numel(eventTypes)
        for n = 1:numel(swarmSizes)
            for r = 1:repetitions
                seed = baseSeed + r - 1;
                eventCounts = zeros(1,numel(protocols));
                for p = 1:numel(protocols)
                    k = k + 1;
                    x = runStochasticEventPerformance(protocols(p), ...
                        swarmSizes(n),eventTypes(e),r,seed);
                    results(k) = normalizeResult(x);
                    eventCounts(p) = x.eventCount;
                end
                if any(eventCounts ~= eventCounts(1))
                    error('runStochasticJoinLeaveStudy:WorkloadMismatch', ...
                        'Paired workload mismatch for %s, N=%d, repetition=%d.', ...
                        eventTypes(e),swarmSizes(n),r);
                end
            end
        end
    end

    study.results = results;
    study.protocols = protocols;
    study.swarmSizes = swarmSizes;
    study.repetitions = repetitions;
    study.baseSeed = baseSeed;
    study.eventTypes = eventTypes;
    study.statistics = summarize(results,protocols,swarmSizes,eventTypes);
end

function out = normalizeResult(x)
    out = x;
    out.leaderTimePerEvent = safeDivide(x.leaderTime,x.successfulEvents);
    out.followerTimePerEvent = safeDivide(x.followerTime,x.successfulEvents);
    out.dtAdmissionTimePerEvent = safeDivide(x.dtAdmissionTime,x.successfulEvents);
    out.messagesPerEvent = safeDivide(x.messageCount,x.successfulEvents);
    out.bytesPerEvent = safeDivide(x.messageBytes,x.successfulEvents);
    out.rekeysPerEvent = safeDivide(x.rekeyCount,x.successfulEvents);
    out.predictedLeavesPerEvent = safeDivide(x.predictedLeaves,x.successfulEvents);
end

function stats = summarize(results,protocols,swarmSizes,eventTypes)
    stats = struct([]);
    k = 0;
    for e = 1:numel(eventTypes)
        for n = 1:numel(swarmSizes)
            for p = 1:numel(protocols)
                k = k + 1;
                mask = string({results.protocol}) == protocols(p) & ...
                    string({results.eventType}) == eventTypes(e) & ...
                    [results.swarmSize] == swarmSizes(n);
                x = results(mask);
                stats(k).protocol = protocols(p);
                stats(k).eventType = eventTypes(e);
                stats(k).swarmSize = swarmSizes(n);
                stats(k).repetitions = numel(x);
                stats(k).eventCountMean = mean([x.eventCount]);
                stats(k).eventCountStd = std([x.eventCount],0,2);
                stats(k).leaderTimeMean = mean([x.leaderTimePerEvent]);
                stats(k).leaderTimeStd = std([x.leaderTimePerEvent],0,2);
                stats(k).followerTimeMean = mean([x.followerTimePerEvent]);
                stats(k).followerTimeStd = std([x.followerTimePerEvent],0,2);
                stats(k).messageMean = mean([x.messagesPerEvent]);
                stats(k).messageStd = std([x.messagesPerEvent],0,2);
                stats(k).bytesMean = mean([x.bytesPerEvent]);
                stats(k).bytesStd = std([x.bytesPerEvent],0,2);
                stats(k).rekeyMean = mean([x.rekeysPerEvent]);
                stats(k).rekeyStd = std([x.rekeysPerEvent],0,2);
                stats(k).predictedLeavesMean = mean([x.predictedLeavesPerEvent]);
                stats(k).predictedLeavesStd = std([x.predictedLeavesPerEvent],0,2);
            end
        end
    end
end

function y = safeDivide(a,b)
    if b == 0, y = 0; else, y = a / b; end
end

function result = emptyResult()
    result = struct('protocol',"",'eventType',"",'runID',0,'randomSeed',0, ...
        'swarmSize',0,'simulationTime',0,'eventRate',0,'eventCount',0, ...
        'successfulEvents',0,'failedEvents',0,'leaderTime',0,'followerTime',0, ...
        'dtAdmissionTime',0,'messageCount',0,'messageBytes',0,'rekeyCount',0, ...
        'predictedLeaves',0,'success',false,'status',"NotExecuted", ...
        'leaderTimePerEvent',0,'followerTimePerEvent',0,'dtAdmissionTimePerEvent',0, ...
        'messagesPerEvent',0,'bytesPerEvent',0,'rekeysPerEvent',0,'predictedLeavesPerEvent',0);
end
