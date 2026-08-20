classdef StatisticsManager < handle

    properties (Access = private)

        cfg

        %-------------------------------
        % Events
        %-------------------------------
        joinEvents = 0
        leaveEvents = 0
        failureEvents = 0

        %-------------------------------
        % DT
        %-------------------------------
        predictedLeaves = 0
        dtPredictionsCreated = 0
        dtPredictionsRealized = 0
        rejectedJoins = 0

        %-------------------------------
        % Rekeying
        %-------------------------------
        localRekeys = 0
        batchRekeys = 0

        % Communication attribution by triggering event.
        joinMessages = 0
        leaveMessages = 0
        failureMessages = 0
        dtDrivenLeaveMessages = 0
        dtBatchMessages = 0

        %-------------------------------
        totalMessages = 0
        totalEncryptions = 0
        totalKeysGenerated = 0
        %-------------------------------
        totalBytes = 0
        communicationCost = 0
        averageMessageSize = 0
        %-------------------------------
        totalDecryptions = 0
        totalHashOperations = 0
        totalRandomNumbers = 0

    end

    methods

        function obj = StatisticsManager(cfg)
            obj.cfg = cfg;
        end

        function incrementJoin(obj)
            obj.joinEvents = obj.joinEvents + 1;
        end

        function incrementLeave(obj)
            obj.leaveEvents = obj.leaveEvents + 1;
        end

        function incrementFailure(obj)
            obj.failureEvents = obj.failureEvents + 1;
        end

        function incrementPredictedLeaves(obj,n)
            if nargin < 2
                n = 1;
            end
            obj.predictedLeaves = obj.predictedLeaves + n;
        end

        function incrementDTPredictionsCreated(obj,n)
            if nargin < 2
                n = 1;
            end
            obj.dtPredictionsCreated = obj.dtPredictionsCreated + n;
        end

        function incrementDTPredictionsRealized(obj,n)
            if nargin < 2
                n = 1;
            end
            obj.dtPredictionsRealized = obj.dtPredictionsRealized + n;
        end

        function incrementRejectedJoin(obj)
            obj.rejectedJoins = obj.rejectedJoins + 1;
        end

        function recordRekey(obj, isBatch, result, eventType)
            if nargin < 4 || isempty(eventType)
                eventType = "unknown";
            else
                eventType = string(eventType);
            end

            obj.totalMessages = obj.totalMessages + result.messagesSent;
            obj.totalEncryptions = obj.totalEncryptions + result.encryptions;
            obj.totalKeysGenerated = obj.totalKeysGenerated + result.keysGenerated;

            messageBytes = result.messagesSent * obj.cfg.messageSize;
            obj.totalBytes = obj.totalBytes + messageBytes;
            obj.communicationCost = obj.totalBytes;

            obj.totalDecryptions = obj.totalDecryptions + result.decryptions;
            obj.totalHashOperations = obj.totalHashOperations + result.hashOperations;
            obj.totalRandomNumbers = obj.totalRandomNumbers + result.randomNumbers;

            if isBatch
                obj.batchRekeys = obj.batchRekeys + 1;
            else
                obj.localRekeys = obj.localRekeys + 1;
            end

            switch eventType
                case "join"
                    obj.joinMessages = obj.joinMessages + result.messagesSent;
                case "leave"
                    obj.leaveMessages = obj.leaveMessages + result.messagesSent;
                case "failure"
                    obj.failureMessages = obj.failureMessages + result.messagesSent;
                case "dtDrivenLeave"
                    obj.dtDrivenLeaveMessages = obj.dtDrivenLeaveMessages + result.messagesSent;
                case "dtBatch"
                    obj.dtBatchMessages = obj.dtBatchMessages + result.messagesSent;
            end
        end

        function n = getJoinEvents(obj), n = obj.joinEvents; end
        function n = getLeaveEvents(obj), n = obj.leaveEvents; end
        function n = getFailureEvents(obj), n = obj.failureEvents; end
        function n = getPredictedLeaves(obj), n = obj.predictedLeaves; end
        function n = getDTPredictionsCreated(obj), n = obj.dtPredictionsCreated; end
        function n = getDTPredictionsRealized(obj), n = obj.dtPredictionsRealized; end
        function n = getRejectedJoins(obj), n = obj.rejectedJoins; end
        function n = getLocalRekeys(obj), n = obj.localRekeys; end
        function n = getBatchRekeys(obj), n = obj.batchRekeys; end

        function stats = getStatistics(obj)
            stats.joinEvents = obj.joinEvents;
            stats.leaveEvents = obj.leaveEvents;
            stats.failureEvents = obj.failureEvents;

            stats.localRekeys = obj.localRekeys;
            stats.batchRekeys = obj.batchRekeys;

            stats.predictedLeaves = obj.predictedLeaves;
            stats.dtPredictionsCreated = obj.dtPredictionsCreated;
            stats.dtPredictionsRealized = obj.dtPredictionsRealized;
            stats.dtPredictionsUnrealized = ...
                max(0, obj.dtPredictionsCreated - obj.dtPredictionsRealized);
            if obj.dtPredictionsCreated > 0
                stats.dtRealizationRatio = ...
                    obj.dtPredictionsRealized / obj.dtPredictionsCreated;
            else
                stats.dtRealizationRatio = NaN;
            end

            stats.rejectedJoins = obj.rejectedJoins;

            stats.joinMessages = obj.joinMessages;
            stats.leaveMessages = obj.leaveMessages;
            stats.failureMessages = obj.failureMessages;
            stats.dtDrivenLeaveMessages = obj.dtDrivenLeaveMessages;
            stats.dtBatchMessages = obj.dtBatchMessages;

            stats.totalMessages = obj.totalMessages;
            stats.totalEncryptions = obj.totalEncryptions;
            stats.totalKeysGenerated = obj.totalKeysGenerated;

            stats.totalBytes = obj.totalBytes;
            stats.communicationCost = obj.communicationCost;

            stats.totalDecryptions = obj.totalDecryptions;
            stats.totalHashOperations = obj.totalHashOperations;
            stats.totalRandomNumbers = obj.totalRandomNumbers;
        end

        function reset(obj)
            obj.joinEvents = 0;
            obj.leaveEvents = 0;
            obj.failureEvents = 0;

            obj.predictedLeaves = 0;
            obj.dtPredictionsCreated = 0;
            obj.dtPredictionsRealized = 0;
            obj.rejectedJoins = 0;

            obj.localRekeys = 0;
            obj.batchRekeys = 0;

            obj.joinMessages = 0;
            obj.leaveMessages = 0;
            obj.failureMessages = 0;
            obj.dtDrivenLeaveMessages = 0;
            obj.dtBatchMessages = 0;

            obj.totalMessages = 0;
            obj.totalEncryptions = 0;
            obj.totalKeysGenerated = 0;

            obj.totalBytes = 0;
            obj.communicationCost = 0;

            obj.totalDecryptions = 0;
            obj.totalHashOperations = 0;
            obj.totalRandomNumbers = 0;
        end

    end

end
