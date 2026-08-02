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

            events = obj.eventFactory.createEvents( ...
                eventCounts, ...
                obj.currentTime);

            for i = 1:numel(events)

                obj.eventQueue.schedule(events{i});

            end

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

        function createEvents(obj, eventCounts)

            for i = 1:eventCounts.join

                uavID = obj.swarm.allocateUAVID();

                % Cluster selection (temporary)
                clusterID = 1;

                event = JoinEvent( ...
                    obj.currentTime, ...
                    uavID, ...
                    clusterID);

                obj.eventQueue.schedule(event);

            end

        end

        function processJoinRequest(obj, uavID, clusterID)

            % ------------------------------------------------------------------
            % Admission Control
            % (DT-assisted admission will be implemented later.)
            % ------------------------------------------------------------------
            accepted = true;

            if ~accepted
                return;
            end

            % ------------------------------------------------------------------
            % Add UAV to the swarm
            % ------------------------------------------------------------------
            obj.swarm.addUAV(uavID, clusterID);

            % ------------------------------------------------------------------
            % Local Rekey
            % (To be implemented.)
            % ------------------------------------------------------------------

            % ------------------------------------------------------------------
            % Statistics
            % (To be implemented.)
            % ------------------------------------------------------------------

        end

        function processLeaveRequest(obj, uavID)

            % ------------------------------------------------------------------
            % Remove UAV
            % ------------------------------------------------------------------
            obj.swarm.removeUAV(uavID);

            % ------------------------------------------------------------------
            % Predictive Batch Rekey
            % (DT enhancement will be implemented later.)
            % ------------------------------------------------------------------

            % ------------------------------------------------------------------
            % Statistics
            % (To be implemented.)
            % ------------------------------------------------------------------

        end

        function processFailure(obj, uavID, reason)

            % ------------------------------------------------------------------
            % Remove failed UAV
            % ------------------------------------------------------------------
            obj.swarm.removeUAV(uavID);

            % ------------------------------------------------------------------
            % Failure reason available for future DT logic
            % ------------------------------------------------------------------
            failureReason = reason;

            % ------------------------------------------------------------------
            % Predictive Batch Rekey
            % (To be implemented.)
            % ------------------------------------------------------------------

            % ------------------------------------------------------------------
            % Statistics
            % (To be implemented.)
            % ------------------------------------------------------------------

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