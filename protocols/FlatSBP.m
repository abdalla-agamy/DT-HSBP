classdef FlatSBP < Protocol

    methods

        function obj = FlatSBP(swarm)

            obj@Protocol(swarm);

        end

        %-----------------------------------

        function initialize(obj)

            fprintf("FlatSBP initialized\n");

        end

        %-----------------------------------

        function join(obj,clusterID)

            JoinEvent.execute(obj.swarm,clusterID);

            % Entire swarm receives new key
            N = obj.swarm.totalUAVs();

            obj.metrics.addCommunication(N);
            obj.metrics.addComputation(N);
            obj.metrics.joins = obj.metrics.joins + 1;

        end

        %-----------------------------------

        function leave(obj,uavID)

            LeaveEvent.execute(obj.swarm,uavID);

            N = obj.swarm.totalUAVs();

            obj.metrics.addCommunication(N);
            obj.metrics.addComputation(N);
            obj.metrics.leaves = obj.metrics.leaves + 1;

        end

        %-----------------------------------

        function failure(obj,uavID)

            FailureEvent.execute(obj.swarm,uavID);
            
            obj.metrics.failures = obj.metrics.failures + 1;

        end

    end

end