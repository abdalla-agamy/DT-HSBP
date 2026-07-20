classdef Simulation < handle

    properties

        swarm
        protocol
        cfg

        currentTime = 0

    end

    methods

        function obj = Simulation(cfg, protocol)

            obj.cfg = cfg;

            obj.protocol = protocol;

            obj.swarm = protocol.swarm;

        end

        function step(obj)

            obj.currentTime = obj.currentTime + 1;

            obj.swarm.step(obj.cfg);

        end

    end

end