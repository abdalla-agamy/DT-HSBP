classdef Simulation < handle

    properties

        swarm
        protocol
        cfg
        eventQueue EventQueue
        eventGenerator
        eventFactory

        dtManager

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

            obj.statistics = StatisticsManager(obj.cfg);

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
            % 9. Advance simulation time
            %--------------------------------------------------------------
            obj.currentTime = obj.currentTime + obj.cfg.timeStep;

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
    % Predict additional departures
    %--------------------------------------------------------------
    predictedLeaves = ...
        obj.dtManager.findUnstableUAVs(uavID);

    for i = 1:numel(predictedLeaves)

        predictedID = predictedLeaves(i);

        obj.dtManager.removeUAV(predictedID);
        obj.swarm.removeUAV(predictedID);

    end

    %--------------------------------------------------------------
    % Remove Digital Twin of requested UAV
    %--------------------------------------------------------------
    obj.dtManager.removeUAV(uavID);

    %--------------------------------------------------------------
    % Protocol owns requested UAV removal and rekey
    %--------------------------------------------------------------
    rekeyResult = obj.protocol.leave(uavID);

    %--------------------------------------------------------------
    % Statistics
    %--------------------------------------------------------------
    if ~isempty(predictedLeaves)

        obj.statistics.incrementPredictedLeaves( ...
            numel(predictedLeaves));

        if ~isempty(rekeyResult)

            obj.statistics.recordRekey(true,rekeyResult);

        end

    else

        obj.statistics.incrementLeave();

        if ~isempty(rekeyResult)

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
    % Predict additional failures
    %--------------------------------------------------------------
    predictedLeaves = ...
        obj.dtManager.findUnstableUAVs(uavID);

    for i = 1:numel(predictedLeaves)

        predictedID = predictedLeaves(i);

        obj.dtManager.removeUAV(predictedID);
        obj.swarm.removeUAV(predictedID);

    end

    %--------------------------------------------------------------
    % Remove Digital Twin of failed UAV
    %--------------------------------------------------------------
    obj.dtManager.removeUAV(uavID);

    %--------------------------------------------------------------
    % Protocol owns failure removal and rekey
    %--------------------------------------------------------------
    rekeyResult = obj.protocol.failure(uavID);

    %--------------------------------------------------------------
    % Statistics
    %--------------------------------------------------------------
    if ~isempty(predictedLeaves)

        obj.statistics.incrementPredictedLeaves( ...
            numel(predictedLeaves));

        if ~isempty(rekeyResult)

            obj.statistics.recordRekey(true,rekeyResult);

        end

    else

        obj.statistics.incrementFailure();

        if ~isempty(rekeyResult)

            obj.statistics.recordRekey(false,rekeyResult);

        end

    end

end

        function result = makeAdmissionDecision(obj, candidateUAV)

%             health = obj.dtManager.predictHealth(candidateUAV);
% 
%             if health > obj.cfg.healthThreshold
% 
%                 result.accepted = true;
%                 result.reason = "Accepted";
% 
%             else
% 
%                 result.accepted = false;
%                 result.reason = "LowHealth";
% 
%             end
            result.accepted = true;
            result.reason = "Accepted";

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

            fprintf('Predicted Leaves   : %d\n', stats.predictedLeaves);
            fprintf('Rejected Joins     : %d\n', stats.rejectedJoins);

            fprintf('Local Rekeys       : %d\n', stats.localRekeys);
            fprintf('Batch Rekeys       : %d\n', stats.batchRekeys);

            fprintf('Messages Sent     : %d\n', ...
                stats.totalMessages);

            fprintf('Bytes Transmitted : %d\n', ...
                stats.totalBytes);

            fprintf('Communication Cost: %.0f\n', ...
                stats.communicationCost);
            
            fprintf('Encryptions       : %d\n', ...
                stats.totalEncryptions);

            fprintf('Decryptions       : %d\n', ...
                stats.totalDecryptions);

            fprintf('Hash Operations   : %d\n', ...
                stats.totalHashOperations);

            fprintf('Random Numbers    : %d\n', ...
                stats.totalRandomNumbers);


            fprintf('===========================================\n');
        end




    end

end