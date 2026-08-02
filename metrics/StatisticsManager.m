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
        

    end

end