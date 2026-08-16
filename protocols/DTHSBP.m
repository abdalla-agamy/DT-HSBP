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

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)

                result = [];

                return;

            end

            cluster = obj.swarm.findCluster(uav.clusterID);

            predictedLeaves = [];

            if ~isempty(cluster)

                members = cluster.getActiveUAVs();

                for i = 1:numel(members)

                    candidate = members(i);

                    if candidate.id == uavID
                        continue;
                    end

                    if candidate.dt.stabilityScore > ...
                            obj.cfg.thetaLeave

                        predictedLeaves(end+1) = candidate.id;

                    end

                end

            end

            for i = 1:numel(predictedLeaves)

                obj.swarm.removeUAV(predictedLeaves(i));

            end

            result = leave@HSBP(obj,uavID);

            if ~isempty(result)

                result.predictedLeaves = predictedLeaves;

            end

        end

        %--------------------------------------------

        function result = failure(obj,uavID)

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)

                result = [];

                return;

            end

            if uav.dt.stabilityScore > obj.cfg.stabilityThreshold

                fprintf("DT detected Failed UAV %d\n",uav.id);

            end

            cluster = obj.swarm.findCluster(uav.clusterID);
            
            predictedLeaves = [];

            if ~isempty(cluster)

                members = cluster.getActiveUAVs();

                for i = 1:numel(members)

                    candidate = members(i);

                    if candidate.id == uavID
                        continue;
                    end

                    if candidate.dt.stabilityScore > ...
                            obj.cfg.thetaLeave

                        predictedLeaves(end+1) = candidate.id;

                    end

                end

            end

            for i = 1:numel(predictedLeaves)

                obj.swarm.removeUAV(predictedLeaves(i));

            end

            result = failure@HSBP(obj,uavID);

            if ~isempty(result)

                result.predictedLeaves = predictedLeaves;

            end

        end

    end

end