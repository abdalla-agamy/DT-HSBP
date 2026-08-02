classdef Simulation < handle

    properties

        swarm
        protocol
        cfg
        eventQueue EventQueue
        eventGenerator
        eventFactory
        dtManager

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

            obj.eventFactory = EventFactory(obj.swarm);

            obj.dtManager = DigitalTwinManager(obj.cfg);

        end

        function step(obj)

            %--------------------------------------------------------------
            % 1. Generate stochastic events
            %--------------------------------------------------------------
            eventCounts = obj.eventGenerator.generate();

            %--------------------------------------------------------------
            % 2. Convert counts into events
            %--------------------------------------------------------------
            events = obj.eventFactory.createEvents( ...
                eventCounts, ...
                obj.currentTime);

            %--------------------------------------------------------------
            % 3. Schedule events
            %--------------------------------------------------------------
            for i = 1:numel(events)

                obj.eventQueue.schedule(events{i});

            end

            %--------------------------------------------------------------
            % 4. Execute scheduled events
            %--------------------------------------------------------------
            obj.processEvents();

            %--------------------------------------------------------------
            % 5. Update Digital Twins
            %--------------------------------------------------------------
            obj.updateDigitalTwins();

            %--------------------------------------------------------------
            % 6. Membership decision
            %--------------------------------------------------------------
            obj.updateMembership();

            %--------------------------------------------------------------
            % 7. Predictive Batch Rekeying
            %--------------------------------------------------------------
            obj.performRekeying();

            %--------------------------------------------------------------
            % 8. Collect statistics
            %--------------------------------------------------------------
            obj.collectStatistics();

            %--------------------------------------------------------------
            % 9. Advance simulation time
            %--------------------------------------------------------------
            obj.currentTime = obj.currentTime + obj.cfg.timeStep;

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
            decision  = obj.makeAdmissionDecision(candidate);

            if ~decision.accepted
                return;
            end

            % ------------------------------------------------------------------
            % Add UAV to the swarm
            % ------------------------------------------------------------------
            obj.swarm.addUAV(uavID, clusterID);

            uav = obj.swarm.findUAV(uavID);

            obj.dtManager.registerUAV(uav);

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
            decision = obj.makeLeaveDecision(uavID);

            if ~decision.approved
                return;
            end

            obj.dtManager.removeUAV(uavID);

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
            decision = obj.makeFailureDecision(uavID, reason);

            if ~decision.approved
                return;
            end

            obj.dtManager.removeUAV(uavID);
            
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

        function result = makeAdmissionDecision(obj, candidateUAV)

            health = obj.dt.predictHealth(candidateUAV);

            if health > obj.cfg.healthThreshold

                result.accepted = true;
                result.reason = "Accepted";

            else

                result.accepted = false;
                result.reason = "LowHealth";

            end

        end

        function decision = makeLeaveDecision(obj, uavID)
            %MAKELEAVEDECISION Evaluate whether a leave request should be processed.
            %
            % INPUT:
            %   uavID - UAV requesting to leave.
            %
            % OUTPUT:
            %   decision.approved - true if the leave request is approved.
            %   decision.reason   - Text describing the decision.

            

            decision.approved = true;
            decision.reason = "Approved";

        end

        function decision = makeFailureDecision(obj, uavID, reason)
            %MAKEFAILUREDECISION Evaluate a detected UAV failure.
            %
            % INPUT:
            %   uavID  - Failed UAV ID.
            %   reason - Failure reason.
            %
            % OUTPUT:
            %   decision.approved - true if the failure should be processed.
            %   decision.reason   - Decision description.

            decision.approved = true;
            decision.reason = "Approved";

        end


        function updateMembership(obj)
            % TODO
        end
        function updateDigitalTwins(obj)
            obj.dtManager.update();
        end
        function performRekeying(obj)
            % TODO
        end
        function collectStatistics(obj)
            % TODO
        end




    end

end