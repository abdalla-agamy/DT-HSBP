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
        generatedJoinEvents = 0
        generatedLeaveEvents = 0
        generatedFailureEvents = 0
        dtDrivenLeaveEvents = 0
        dtCollateralDepartureEvents = 0

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

            obj.cfg.currentTime = obj.currentTime;

            %--------------------------------------------------------------
            % 1. Generate stochastic membership events
            %--------------------------------------------------------------
            suppressMembershipEvents = false;
            if isfield(obj.cfg,'dtIntegrationSuppressMembershipEvents')
                suppressMembershipEvents = ...
                    logical(obj.cfg.dtIntegrationSuppressMembershipEvents);
            end

            if suppressMembershipEvents
                eventCounts.join = 0;
                eventCounts.leave = 0;
                eventCounts.failure = 0;
            else
                eventCounts = obj.eventGenerator.generate();
            end

            obj.generatedJoinEvents = obj.generatedJoinEvents + eventCounts.join;
            obj.generatedLeaveEvents = obj.generatedLeaveEvents + eventCounts.leave;
            obj.generatedFailureEvents = obj.generatedFailureEvents + eventCounts.failure;

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
            %--------------------------------------------------------------
            obj.swarm.step(obj.cfg);
            obj.currentTime = obj.currentTime + obj.cfg.timeStep;
            obj.cfg.currentTime = obj.currentTime;
            obj.updateDigitalTwins();

            %--------------------------------------------------------------
            % 7. Materialize persistent DT predicted departures
            %--------------------------------------------------------------
            obj.schedulePredictedDepartures();

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

        function processPredictedDeparture(obj,uavID,reason)

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav) || ~uav.active
                return;
            end

            obj.dtDrivenLeaveEvents = obj.dtDrivenLeaveEvents + 1;
            obj.processLeaveRequest(uavID);

        end

        function schedulePredictedDepartures(obj)

            if ~isa(obj.protocol,"DTHSBP")
                return;
            end

            enabled = false;
            if isfield(obj.cfg,'dtPredictedDepartureEnabled')
                enabled = logical(obj.cfg.dtPredictedDepartureEnabled);
            end

            if ~enabled
                return;
            end

            currentTime = obj.currentTime;
            departureTime = currentTime + obj.cfg.predictionHorizon;
            activeUAVs = obj.swarm.getActiveUAVs();

            for i = 1:numel(activeUAVs)
                uav = activeUAVs(i);

                if isempty(uav.dt)
                    continue;
                end

                if ~uav.dt.predictedLeave
                    continue;
                end

                if isnan(uav.dt.predictionTime)
                    continue;
                end

                if abs(uav.dt.predictionTime - currentTime) > 1e-12
                    continue;
                end

                probability = obj.computeDTDepartureProbability( ...
                    uav.dt.stabilityScore, ...
                    obj.cfg.predictionHorizon);

                if rand() > probability
                    continue;
                end

                obj.statistics.incrementDTPredictionsRealized();

                obj.eventQueue.schedule( ...
                    DTPredictedDepartureEvent( ...
                        departureTime, ...
                        uav.id, ...
                        "DT-predicted instability"));
            end

        end

        function probability = computeDTDepartureProbability(obj, stabilityScore, horizon)
            validateattributes(stabilityScore, ...
                {'numeric'}, {'scalar','real','finite','nonnegative'});
            validateattributes(horizon, ...
                {'numeric'}, {'scalar','real','finite','nonnegative'});

            if ~isfield(obj.cfg,'dtDepartureHazardModel') || ...
                    string(obj.cfg.dtDepartureHazardModel) ~= ...
                    "threshold_anchored_exponential"
                error('Simulation:UnsupportedDTHazardModel', ...
                    'Unsupported DT departure hazard model.');
            end

            theta = obj.cfg.thetaLeave;
            leaveRate = obj.cfg.leaveRate;

            if stabilityScore <= 0 || theta <= 0 || leaveRate <= 0 || horizon <= 0
                probability = 0;
                return;
            end

            hazard = leaveRate * exp(stabilityScore / theta - 1);
            probability = 1 - exp(-hazard * horizon);
            probability = max(0,min(1,probability));
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
            rekeyResult = obj.protocol.join(uavID,clusterID);

            if isempty(rekeyResult)
                obj.statistics.incrementRejectedJoin();
                return;
            end

            uav = obj.swarm.findUAV(uavID);
            if ~isempty(uav)
                obj.dtManager.registerUAV(uav);
            end

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

            rekeyResult = obj.protocol.leave(uavID);
            obj.dtManager.removeUAV(uavID);

            if ~isempty(rekeyResult)
                predictedLeaves = rekeyResult.predictedLeaves;
                for i = 1:numel(predictedLeaves)
                    obj.dtManager.removeUAV(predictedLeaves(i));
                end
            end

            obj.statistics.incrementLeave();

            if ~isempty(rekeyResult)
                if ~isempty(rekeyResult.predictedLeaves)
                    collateralCount = numel(rekeyResult.predictedLeaves);
                    obj.dtCollateralDepartureEvents = ...
                        obj.dtCollateralDepartureEvents + collateralCount;
                    obj.statistics.incrementPredictedLeaves(collateralCount);
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

            rekeyResult = obj.protocol.failure(uavID);
            obj.dtManager.removeUAV(uavID);

            if ~isempty(rekeyResult)
                predictedLeaves = rekeyResult.predictedLeaves;
                for i = 1:numel(predictedLeaves)
                    obj.dtManager.removeUAV(predictedLeaves(i));
                end
            end

            obj.statistics.incrementFailure();

            if ~isempty(rekeyResult)
                if ~isempty(rekeyResult.predictedLeaves)
                    collateralCount = numel(rekeyResult.predictedLeaves);
                    obj.dtCollateralDepartureEvents = ...
                        obj.dtCollateralDepartureEvents + collateralCount;
                    obj.statistics.incrementPredictedLeaves(collateralCount);
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
            activeUAVs = obj.swarm.getActiveUAVs();
            for i = 1:numel(activeUAVs)
                activeUAVs(i).dt.cfg.currentTime = obj.currentTime;
            end

            previousPredictions = false(1,numel(activeUAVs));
            for i = 1:numel(activeUAVs)
                previousPredictions(i) = activeUAVs(i).dt.predictedLeave;
            end

            obj.dtManager.update();

            for i = 1:numel(activeUAVs)
                if ~previousPredictions(i) && activeUAVs(i).dt.predictedLeave
                    obj.statistics.incrementDTPredictionsCreated();
                end
            end
        end

        function printStatistics(obj)
            stats = obj.statistics.getStatistics();

            fprintf('\n');
            fprintf('========== Simulation Statistics ==========\n');
            fprintf('Join Events        : %d\n', stats.joinEvents);
            fprintf('Leave Events       : %d\n', stats.leaveEvents);
            fprintf('Failure Events     : %d\n', stats.failureEvents);
            fprintf('DT Disturbances    : %d\n', obj.dtDisturbanceCount);
            fprintf('DT Predictions     : %d\n', stats.dtPredictionsCreated);
            fprintf('DT Realized        : %d\n', stats.dtPredictionsRealized);
            fprintf('DT Unrealized      : %d\n', stats.dtPredictionsUnrealized);
            fprintf('DT Realization     : %.6f\n', stats.dtRealizationRatio);
            fprintf('Predicted Leaves   : %d\n', stats.predictedLeaves);
            fprintf('DT Driven Leaves   : %d\n', obj.dtDrivenLeaveEvents);
            fprintf('DT Collateral      : %d\n', obj.dtCollateralDepartureEvents);
            fprintf('Rejected Joins     : %d\n', stats.rejectedJoins);
            fprintf('Local Rekeys       : %d\n', stats.localRekeys);
            fprintf('Batch Rekeys       : %d\n', stats.batchRekeys);
            fprintf('Messages Sent      : %d\n', stats.totalMessages);
            fprintf('Bytes Transmitted  : %d\n', stats.totalBytes);
            fprintf('Communication Cost : %.0f\n', stats.communicationCost);
            fprintf('Encryptions        : %d\n', stats.totalEncryptions);
            fprintf('Decryptions        : %d\n', stats.totalDecryptions);
            fprintf('Hash Operations    : %d\n', stats.totalHashOperations);
            fprintf('Random Numbers     : %d\n', stats.totalRandomNumbers);
            fprintf('===========================================\n');
        end

    end

end
