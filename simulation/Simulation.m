classdef Simulation < handle

    properties

        swarm
        protocol
        cfg
        eventQueue EventQueue
        eventGenerator
        eventFactory
        dtDisturbanceGenerator

        dtManager

        statistics
        currentTime = 0
        dtDisturbanceCount = 0

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
            obj.dtDisturbanceGenerator = DTDisturbanceGenerator(obj.cfg);

            obj.dtManager = DigitalTwinManager(obj.cfg);

            initialUAVs = obj.swarm.getActiveUAVs();

            for i = 1:numel(initialUAVs)
                obj.dtManager.registerUAV(initialUAVs(i));
            end

            obj.statistics = StatisticsManager(obj.cfg);

        end

        function step(obj)

            %--------------------------------------------------------------
            % 1. Generate stochastic membership events
            %--------------------------------------------------------------
            eventCounts = obj.eventGenerator.generate();

            %--------------------------------------------------------------
            % 2. Convert membership counts into events
            %--------------------------------------------------------------
            events = obj.eventFactory.createEvents( ...
                eventCounts, ...
                obj.currentTime);

            %--------------------------------------------------------------
            % 3. Schedule membership events
            %--------------------------------------------------------------
            for i = 1:numel(events)
                obj.eventQueue.schedule(events{i});
            end

            %--------------------------------------------------------------
            % 4. Generate independent physical DT disturbances
            %--------------------------------------------------------------
            disturbanceCount = obj.dtDisturbanceGenerator.generate();
            disturbanceEvents = obj.createDisturbanceEvents(disturbanceCount);

            for i = 1:numel(disturbanceEvents)
                obj.eventQueue.schedule(disturbanceEvents{i});
            end

            %--------------------------------------------------------------
            % 5. Execute events scheduled for this simulation time
            %--------------------------------------------------------------
            obj.processEvents();

            %--------------------------------------------------------------
            % 6. Advance physical state and Digital Twin observation
            %
            % A disturbance is applied before the physical step. Therefore
            % the next DT update compares the disturbed state at t+dt
            % against the prediction that was made for t+dt, preserving
            % the intended one-step prediction residual.
            %--------------------------------------------------------------
            obj.swarm.step(obj.cfg);
            obj.updateDigitalTwins();

            %--------------------------------------------------------------
            % 7. Advance simulation time
            %--------------------------------------------------------------
            obj.currentTime = obj.currentTime + obj.cfg.timeStep;

        end

        function events = createDisturbanceEvents(obj, count)
            events = {};

            if count <= 0
                return;
            end

            for k = 1:count
                cluster = obj.selectDisturbanceCluster();

                if isempty(cluster)
                    continue;
                end

                activeUAVs = cluster.getActiveUAVs();
                if isempty(activeUAVs)
                    continue;
                end

                requestedCount = obj.cfg.dtDisturbanceUAVCount;
                requestedCount = max(1, floor(requestedCount));
                selectedCount = min(requestedCount, numel(activeUAVs));

                if selectedCount == numel(activeUAVs)
                    selected = activeUAVs;
                else
                    selected = activeUAVs(randperm(numel(activeUAVs), selectedCount));
                end

                ids = [selected.id];

                events{end+1} = DTDisturbanceEvent( ...
                    obj.currentTime, ...
                    cluster.id, ...
                    ids, ...
                    obj.cfg.dtDisturbancePositionStep, ...
                    obj.cfg.dtDisturbanceVelocityStep, ...
                    obj.cfg.dtDisturbanceEnergyDrop);
            end

            obj.dtDisturbanceCount = obj.dtDisturbanceCount + numel(events);
        end

        function cluster = selectDisturbanceCluster(obj)
            eligible = [];

            for i = 1:numel(obj.swarm.clusters)
                if ~isempty(obj.swarm.clusters(i).getActiveUAVs())
                    eligible(end+1) = i;
                end
            end

            if isempty(eligible)
                cluster = [];
                return;
            end

            index = eligible(randi(numel(eligible)));
            cluster = obj.swarm.clusters(index);
        end

        function run(obj)

            while obj.currentTime < obj.cfg.simulationTime
                obj.step();
            end

        end

        function processEvents(obj)

            dueEvents = obj.eventQueue.popDueEvents(obj.currentTime);

            for i = 1:numel(dueEvents)
                dueEvents{i}.execute(obj);
            end

        end

        function processJoinRequest(obj,uavID,clusterID)

            %--------------------------------------------------------------
            % Protocol-specific admission and join
            %--------------------------------------------------------------
            rekeyResult = obj.protocol.join(uavID,clusterID);

            %--------------------------------------------------------------
            % Join rejected
            %--------------------------------------------------------------
            if isempty(rekeyResult)
                obj.statistics.incrementRejectedJoin();
                return;
            end

            %--------------------------------------------------------------
            % Register Digital Twin after successful admission
            %--------------------------------------------------------------
            uav = obj.swarm.findUAV(uavID);

            if ~isempty(uav)
                obj.dtManager.registerUAV(uav);
            end

            %--------------------------------------------------------------
            % Statistics
            %--------------------------------------------------------------
            obj.statistics.incrementJoin();
            obj.statistics.recordRekey(false,rekeyResult);

        end

        function processLeaveRequest(obj,uavID)

            decision = obj.makeLeaveDecision(uavID);

            if ~decision.approved
                return;
            end

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)
                return;
            end

            %--------------------------------------------------------------
            % Protocol owns requested and predicted UAV removal
            %--------------------------------------------------------------
            rekeyResult = obj.protocol.leave(uavID);

            obj.dtManager.removeUAV(uavID);

            if ~isempty(rekeyResult)

                predictedLeaves = rekeyResult.predictedLeaves;

                for i = 1:numel(predictedLeaves)
                    obj.dtManager.removeUAV(predictedLeaves(i));
                end

            end

            %--------------------------------------------------------------
            % Statistics
            %--------------------------------------------------------------
            obj.statistics.incrementLeave();

            if ~isempty(rekeyResult)

                if ~isempty(rekeyResult.predictedLeaves)

                    obj.statistics.incrementPredictedLeaves( ...
                        numel(rekeyResult.predictedLeaves));

                    obj.statistics.recordRekey(true,rekeyResult);

                else
                    obj.statistics.recordRekey(false,rekeyResult);
                end

            end

        end

        function processFailure(obj,uavID,reason)

            decision = obj.makeFailureDecision(uavID,reason);

            if ~decision.approved
                return;
            end

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)
                return;
            end

            %--------------------------------------------------------------
            % Protocol owns requested and predicted UAV removal
            %--------------------------------------------------------------
            rekeyResult = obj.protocol.failure(uavID);

            obj.dtManager.removeUAV(uavID);

            if ~isempty(rekeyResult)

                predictedLeaves = rekeyResult.predictedLeaves;

                for i = 1:numel(predictedLeaves)
                    obj.dtManager.removeUAV(predictedLeaves(i));
                end

            end

            %--------------------------------------------------------------
            % Statistics
            %--------------------------------------------------------------
            obj.statistics.incrementFailure();

            if ~isempty(rekeyResult)

                if ~isempty(rekeyResult.predictedLeaves)

                    obj.statistics.incrementPredictedLeaves( ...
                        numel(rekeyResult.predictedLeaves));

                    obj.statistics.recordRekey(true,rekeyResult);

                else
                    obj.statistics.recordRekey(false,rekeyResult);
                end

            end

        end

        function result = makeAdmissionDecision(obj, candidateUAV)

            result.accepted = true;
            result.reason = "Accepted";

        end

        function decision = makeLeaveDecision(obj, uavID)
            decision.approved = true;
            decision.reason = "Approved";
        end

        function decision = makeFailureDecision(obj, uavID, reason)
            decision.approved = true;
            decision.reason = "Approved";
        end

        function updateDigitalTwins(obj)
            obj.dtManager.update();
        end

        function printStatistics(obj)
            stats = obj.statistics.getStatistics();

            fprintf('\n');
            fprintf('========== Simulation Statistics ==========\n');

            fprintf('Join Events        : %d\n', stats.joinEvents);
            fprintf('Leave Events       : %d\n', stats.leaveEvents);
            fprintf('Failure Events     : %d\n', stats.failureEvents);
            fprintf('DT Disturbances    : %d\n', obj.dtDisturbanceCount);

            fprintf('Predicted Leaves   : %d\n', stats.predictedLeaves);
            fprintf('Rejected Joins     : %d\n', stats.rejectedJoins);
            fprintf('Local Rekeys       : %d\n', stats.localRekeys);
            fprintf('Batch Rekeys       : %d\n', stats.batchRekeys);
            fprintf('Messages Sent     : %d\n', stats.totalMessages);
            fprintf('Bytes Transmitted : %d\n', stats.totalBytes);
            fprintf('Communication Cost: %.0f\n', stats.communicationCost);
            fprintf('Encryptions       : %d\n', stats.totalEncryptions);
            fprintf('Decryptions       : %d\n', stats.totalDecryptions);
            fprintf('Hash Operations   : %d\n', stats.totalHashOperations);
            fprintf('Random Numbers    : %d\n', stats.totalRandomNumbers);

            fprintf('===========================================\n');
        end

    end

end