classdef HSBP < Protocol

    methods

        function obj = HSBP(swarm)

            obj@Protocol(swarm);

        end

        %--------------------------------------------

        function initialize(obj)

            fprintf("HSBP initialized\n");

        end

        %--------------------------------------------

        function join(obj,clusterID)

            JoinEvent.execute(obj.swarm,clusterID);

            cluster = obj.swarm.clusters(clusterID);

            cluster.groupKey = ...
                obj.engine.generateGroupKey(cluster.uavs);

            obj.addCost(cluster.count());

            obj.recordJoin();

        end

        %--------------------------------------------

        function leave(obj,uavID)

            u = obj.swarm.findUAV(uavID);

            if isempty(u)
                return;
            end

            clusterID = u.clusterID;

            LeaveEvent.execute(obj.swarm,uavID);

            cluster = obj.swarm.clusters(clusterID);


            cluster.groupKey = ...
                obj.engine.generateGroupKey(cluster.uavs);

            n = cluster.count();

            obj.metrics.addCommunication(n);
            obj.metrics.addComputation(n);

            obj.metrics.leaves = obj.metrics.leaves + 1;

        end

        %--------------------------------------------

        function failure(obj,uavID)

            FailureEvent.execute(obj.swarm,uavID);

            obj.metrics.failures = ...
                obj.metrics.failures + 1;

        end

    end

end