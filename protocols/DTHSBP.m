classdef DTHSBP < HSBP
    methods

        function obj = DTHSBP(swarm)

            obj@HSBP(swarm);

        end

        %--------------------------------------------

        function initialize(obj)

            fprintf("DTHSBP initialized\n");

        end

        %--------------------------------------------

        function join(obj, clusterID)

    cfg = obj.cfg;

    % Create candidate UAV
    newID = obj.swarm.nextUAVID;

    candidate = UAV(newID, clusterID, cfg);

    % DT evaluation
    candidate.dt.update();

    if StabilityModel.canJoin( ...
            candidate.dt.stabilityScore, ...
            cfg)

        % Accept UAV
        obj.swarm.nextUAVID = obj.swarm.nextUAVID + 1;

        obj.swarm.clusters(clusterID).addUAV(candidate);

        % Rekey affected cluster
        cluster = obj.swarm.findCluster(clusterID);

        activeUAVs = cluster.getActiveUAVs();

        newGroupKey = ...
            obj.engine.generateGroupKey(activeUAVs);

        cluster.groupKey = newGroupKey;

        for i = 1:numel(activeUAVs)

            activeUAVs(i).groupKey = newGroupKey;
            activeUAVs(i).keySynced = true;

        end

        obj.addCost(cluster.count());

        obj.recordJoin();

    else

        fprintf("Join rejected by DT.\n");

    end

end

        %--------------------------------------------

        function leave(obj,uavID)

    u = obj.swarm.findUAV(uavID);

    if isempty(u)
        return;
    end

    if u.dt.stabilityScore > obj.cfg.thetaLeave

        fprintf("DT detected unstable UAV %d\n",u.id);

    end

    leave@HSBP(obj,uavID);

end

        %--------------------------------------------

%         function failure(obj,uavID)
% 
%             FailureEvent.execute(obj.swarm,uavID);
% 
%             obj.metrics.failures = ...
%                 obj.metrics.failures + 1;
% 
%         end

    end

end