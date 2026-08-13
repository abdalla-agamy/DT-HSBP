classdef EventFactory < handle

    properties (Access = private)

        swarm

    end

    methods

        function obj = EventFactory(swarm)

            obj.swarm = swarm;

        end

        function events = createEvents(obj, eventCounts, currentTime)

            events = {};

            %--------------------------------------------------------------
            % Join Events
            %--------------------------------------------------------------
            for i = 1:eventCounts.join

                uavID = obj.swarm.nextUAVID;

                % Temporary cluster selection
                clusterID = 1;

                events{end+1} = JoinEvent( ...
                    currentTime, ...
                    uavID, ...
                    clusterID);

            end

            %--------------------------------------------------------------
            % Leave Events
            %--------------------------------------------------------------
            activeUAVs = obj.swarm.getActiveUAVs();

            leaveIndices = [];

            if ~isempty(activeUAVs)

                numLeaves = min(eventCounts.leave, numel(activeUAVs));

                leaveIndices = randperm(numel(activeUAVs), numLeaves);

                for i = 1:numLeaves

                    uav = activeUAVs(leaveIndices(i));

                    events{end+1} = LeaveEvent( ...
                        currentTime, ...
                        uav.id, ...
                        uav.clusterID);

                end

            end

            %--------------------------------------------------------------
            % Failure Events
            %--------------------------------------------------------------
            remaining = activeUAVs;

            remaining(leaveIndices) = [];

            numFailures = min(eventCounts.failure, numel(remaining));

            if numFailures > 0

                failureIndices = randperm(numel(remaining), numFailures);

                for i = 1:numFailures

                    uav = remaining(failureIndices(i));

                    events{end+1} = FailureEvent( ...
                        currentTime, ...
                        uav.id, ...
                        "RandomFailure");

                end

            end


        end
    end

end