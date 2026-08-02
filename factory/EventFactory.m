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

                uavID = obj.swarm.allocateUAVID();

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

            if ~isempty(activeUAVs)

                numLeaves = min(eventCounts.leave, numel(activeUAVs));

                indices = randperm(numel(activeUAVs), numLeaves);

                for i = 1:numLeaves

                    uav = activeUAVs(indices(i));

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

            remaining(indices) = [];

            numFailures = min(eventCounts.failure, numel(remaining));

            indices = randperm(numel(remaining), numFailures);

            for i = 1:numFailures

                uav = remaining(indices(i));

                events{end+1} = FailureEvent( ...
                    currentTime, ...
                    uav.id, ...
                    "RandomFailure");

            end


        end
    end

end