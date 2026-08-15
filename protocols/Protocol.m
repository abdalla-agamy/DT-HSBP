classdef (Abstract) Protocol < handle

    properties
        swarm
        cfg

        metrics
        engine
        rekeyManager
    end

    methods (Abstract)

        initialize(obj)

        result = join(obj,uavID,clusterID)

        result = leave(obj,uavID)

        result = failure(obj,uavID)

    end

    methods

        function obj = Protocol(swarm)

            obj.swarm = swarm;
            obj.cfg = swarm.config;
            obj.metrics = Metrics();
            obj.engine = SBPEngine(obj.cfg);
            obj.rekeyManager = RekeyManager(obj.cfg);

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
    methods (Access = protected)

        function result = createRekeyResult( ...
                obj,affectedUAVs,clusterID)

            result = obj.rekeyManager.buildResult( ...
                affectedUAVs,clusterID);

        end

    end



end