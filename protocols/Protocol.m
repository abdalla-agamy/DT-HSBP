classdef (Abstract) Protocol < handle

    properties
        swarm
        cfg

        metrics
        engine
    end

    methods

        function obj = Protocol(swarm)

            obj.swarm = swarm;
            obj.cfg = swarm.config;
            obj.metrics = Metrics();
            obj.engine = SBPEngine(obj.cfg);

        end

    end

    methods

        function recordJoin(obj)

            obj.metrics.joins = obj.metrics.joins + 1;

        end

        function recordLeave(obj)

            obj.metrics.leaves = obj.metrics.leaves + 1;

        end

        function recordFailure(obj)

            obj.metrics.failures = ...
                obj.metrics.failures + 1;

        end

        function addCost(obj,cost)

            obj.metrics.addCommunication(cost);
            obj.metrics.addComputation(cost);

        end

    end

    methods (Abstract)

        initialize(obj)

        join(obj,clusterID)

        leave(obj,uavID)

        failure(obj,uavID)

    end

end