classdef StatisticsManager < handle

    properties (Access = private)

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
        rejectedJoins = 0

        %-------------------------------
        % Rekeying
        %-------------------------------
        localRekeys = 0
        batchRekeys = 0

    end

    methods

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

            obj.predictedLeaves = ...
                obj.predictedLeaves + n;

        end

        function incrementRejectedJoin(obj)

            obj.rejectedJoins = ...
                obj.rejectedJoins + 1;

        end

        function recordRekey(obj, isBatch)

            obj.localRekeys = ...
                obj.localRekeys + 1;
            if isBatch
                obj.batchRekeys = ...
                    obj.batchRekeys + 1;
            end

        end
        function n = getJoinEvents(obj)

            n = obj.joinEvents;

        end
        function n = getLeaveEvents(obj)

            n = obj.leaveEvents;

        end
        function n = getFailureEvents(obj)

            n = obj.failureEvents;

        end
        function n = getPredictedLeaves(obj)

            n = obj.predictedLeaves;

        end
        function n = getRejectedJoins(obj)

            n = obj.rejectedJoins;

        end
        function n = getLocalRekeys(obj)

            n = obj.localRekeys;

        end
        function n = getBatchRekeys(obj)

            n = obj.batchRekeys;

        end
        function stats = getStatistics(obj)

            stats.joinEvents = obj.joinEvents;
            stats.leaveEvents = obj.leaveEvents;
            stats.failureEvents = obj.failureEvents;

            stats.localRekeys = obj.localRekeys;
            stats.batchRekeys = obj.batchRekeys;

            stats.predictedLeaves = obj.predictedLeaves;
            stats.rejectedJoins = obj.rejectedJoins;

        end

        function reset(obj)
            %RESET Clear all collected statistics.

            obj.joinEvents = 0;
            obj.leaveEvents = 0;
            obj.failureEvents = 0;

            obj.predictedLeaves = 0;
            obj.rejectedJoins = 0;

            obj.localRekeys = 0;
            obj.batchRekeys = 0;

        end
        
        

    end

end