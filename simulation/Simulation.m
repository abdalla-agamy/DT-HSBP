classdef Simulation < handle

    properties

        swarm
        protocol
        cfg
        eventQueue EventQueue
        eventGenerator


        currentTime = 0

    end

    methods

        function obj = Simulation(cfg, protocol)

            obj.cfg = cfg;

            obj.protocol = protocol;

            obj.swarm = protocol.swarm;

            obj.currentTime = 0;

            obj.eventQueue = EventQueue();

            obj.eventGenerator = PoissonEventGenerator(obj.cfg);

        end

        function step(obj)

            % Advance simulation clock
            obj.currentTime = obj.currentTime + obj.cfg.timeStep;

            % Generate stochastic events
            eventCounts = obj.eventGenerator.generate();

            % Process generated events
            obj.processEvents(eventCounts);

            % Update physical UAV states
            obj.updatePhysicalWorld();

            % Update Digital Twin models
            obj.updateDigitalTwins();

            % Execute protocol operations
            obj.executeHSBP();

            % Collect simulation statistics
            obj.collectStatistics();

        end

        function run(obj)

            while obj.currentTime < obj.cfg.simulationTime

                obj.step();

            end

        end

        function processEvents(obj,eventCounts)

            dueEvents = obj.eventQueue.popDueEvents(obj.currentTime);

            for i = 1:numel(dueEvents)

                dueEvents(i).execute(obj);

            end

        end
        function updatePhysicalWorld(obj)
        end
        function updateDigitalTwins(obj)
        end
        function executeHSBP(obj)
        end
        function collectStatistics(obj)
        end


    end

end