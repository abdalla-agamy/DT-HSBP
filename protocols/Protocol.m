classdef (Abstract) Protocol < handle

    properties
        swarm
        cfg

        metrics
    end

    methods

        function obj = Protocol(swarm)

            obj.swarm = swarm;
            obj.cfg = swarm.config;
            obj.metrics = Metrics();

        end

    end

    methods (Abstract)

        initialize(obj)

        join(obj,clusterID)

        leave(obj,uavID)

        failure(obj,uavID)

    end

end