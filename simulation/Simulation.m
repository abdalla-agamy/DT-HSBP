classdef Simulation < handle

    properties

        swarm
        protocol
        cfg
        eventQueue EventQueue
        eventGenerator
        eventFactory

        dtManager
        rekeyManager

        statistics
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
            obj.rekeyManager = RekeyManager(obj.cfg);

            obj.statistics = StatisticsManager();

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

                dueEvents{i}.execute(obj);

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
                obj.statistics.incrementRejectedJoin();
                return;
            end

            % ------------------------------------------------------------------
            % Add UAV to the swarm
            % ------------------------------------------------------------------
            obj.swarm.addUAV(uavID, clusterID);

            %--------------------------------------------------------------
            % Register Digital Twin
            %--------------------------------------------------------------
            uav = obj.swarm.findUAV(uavID);

            obj.dtManager.registerUAV(uav);

            % ------------------------------------------------------------------
            % Local Rekey
            % ------------------------------------------------------------------
            cluster = obj.swarm.findCluster(clusterID);

            obj.rekeyManager.performLocalRekey(cluster);

            % ------------------------------------------------------------------
            % Statistics
            % ------------------------------------------------------------------
            obj.statistics.incrementJoin();
            
            obj.statistics.recordRekey(false);
            

        end

        function processLeaveRequest(obj, uavID)


            decision = obj.makeLeaveDecision(uavID);

            if ~decision.approved
                return;
            end

            uav = obj.swarm.findUAV(uavID);

            clusterID = uav.clusterID;

            %--------------------------------------------------------------
            % Predict additional departures
            %--------------------------------------------------------------
            predictedLeaves = obj.dtManager.findUnstableUAVs(uavID);
            predictedLeaves(end+1)=uavID;

            for i = 1:numel(predictedLeaves)

                predictedID = predictedLeaves(i);

                obj.dtManager.removeUAV(predictedID);   % Remove Digital Twin

                obj.swarm.removeUAV(predictedID);       % Remove UAV

            end

            % ------------------------------------------------------------------
            % Predictive Batch Rekey
            % ------------------------------------------------------------------

            cluster = obj.swarm.findCluster(clusterID);

            obj.rekeyManager.performLocalRekey(cluster);

            % ------------------------------------------------------------------
            % Statistics
            % ------------------------------------------------------------------
            obj.statistics.incrementLeave();
            obj.statistics.incrementPredictedLeaves( ...
                numel(predictedLeaves)-1);

            if ~isempty(predictedLeaves)
                obj.statistics.recordRekey(true);
            else
                obj.statistics.recordRekey(false);
            end

        end

        function processFailure(obj, uavID, reason)


            decision = obj.makeFailureDecision(uavID, reason);

            if ~decision.approved
                return;
            end

            uav = obj.swarm.findUAV(uavID);

            clusterID = uav.clusterID;

            %--------------------------------------------------------------
            % Predict additional failure
            %--------------------------------------------------------------
            predictedLeaves = obj.dtManager.findUnstableUAVs(uavID);
            predictedLeaves(end+1)=uavID;

            for i = 1:numel(predictedLeaves)

                predictedID = predictedLeaves(i);

                obj.dtManager.removeUAV(predictedID);   % Remove Digital Twin

                obj.swarm.removeUAV(predictedID);       % Remove UAV

            end

            % ------------------------------------------------------------------
            % Failure reason available for future DT logic
            % ------------------------------------------------------------------
            failureReason = reason;

            % ------------------------------------------------------------------
            % Predictive Batch Rekey
            % (To be implemented.)
            % ------------------------------------------------------------------
            cluster = obj.swarm.findCluster(clusterID);

            obj.rekeyManager.performLocalRekey(cluster);

            % ------------------------------------------------------------------
            % Statistics
            % ------------------------------------------------------------------
            obj.statistics.incrementFailure();
            obj.statistics.incrementPredictedLeaves( ...
                numel(predictedLeaves)-1);

            if ~isempty(predictedLeaves)
                obj.statistics.recordRekey(true);
            else
                obj.statistics.recordRekey(false);
            end

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

        function printStatistics(obj)
            stats = obj.statistics.getStatistics();

            fprintf('\n');
            fprintf('========== Simulation Statistics ==========\n');

            fprintf('Join Events        : %d\n', stats.joinEvents);
            fprintf('Leave Events       : %d\n', stats.leaveEvents);
            fprintf('Failure Events     : %d\n', stats.failureEvents);

            fprintf('Predicted Leaves   : %d\n', stats.predictedLeaves);
            fprintf('Rejected Joins     : %d\n', stats.rejectedJoins);

            fprintf('Local Rekeys       : %d\n', stats.localRekeys);
            fprintf('Batch Rekeys       : %d\n', stats.batchRekeys);

            fprintf('===========================================\n');
        end




    end

end