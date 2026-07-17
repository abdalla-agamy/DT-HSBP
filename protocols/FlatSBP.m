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

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordJoin();

        end

        %-----------------------------------

        function leave(obj,uavID)

            LeaveEvent.execute(obj.swarm,uavID);

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordLeave();


        end

        %-----------------------------------

        function failure(obj,uavID)

            FailureEvent.execute(obj.swarm,uavID);

            obj.recordFailure();

        end

    end

end