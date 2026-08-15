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

        function result = join(obj,uavID,clusterID)

            cfg = obj.cfg;

            % Create candidate UAV using the ID reserved by EventFactory
            candidate = UAV(uavID,clusterID,cfg);

            % DT evaluation
            candidate.dt.update();

            if StabilityModel.canJoin( ...
                    candidate.dt.stabilityScore, ...
                    cfg)

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

                result = obj.createRekeyResult( ...
    activeUAVs, ...
    clusterID);

                obj.addCost(cluster.count());

                obj.recordJoin();

            else
                result = [];

                fprintf("Join rejected by DT.\n");

            end

        end

        %--------------------------------------------

        function result = leave(obj,uavID)

            u = obj.swarm.findUAV(uavID);

            if isempty(u)
                result =[];
                return;
            end

            if u.dt.stabilityScore > obj.cfg.thetaLeave

                fprintf("DT detected unstable UAV %d\n",u.id);

            end

            result = leave@HSBP(obj,uavID);

        end

        %--------------------------------------------

        function result=failure(obj,uavID)

            u = obj.swarm.findUAV(uavID);

            if isempty(u)
                result =[];
                return;
            end

            if u.dt.stabilityScore > obj.cfg.stabilityThreshold

                fprintf("DT detected Failed UAV %d\n",u.id);

            end

            result = failure@HSBP(obj,uavID);

        end

    end

end