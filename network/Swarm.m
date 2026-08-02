classdef Swarm < handle

    properties
        clusters        % Array of Cluster objects
        leader          % Swarm Leader (SL)
        config
        nextUAVID
    end

    methods

        %------------------------------------------

        function obj = Swarm(cfg)

            obj.config = cfg;
            obj.clusters = Cluster.empty;

            % Create clusters
            for c = 1:cfg.numClusters
                obj.clusters(end+1) = Cluster(c);
            end

            % Create UAVs
            id = 1;

            for c = 1:cfg.numClusters

                for k = 1:cfg.clusterSize

                    u = UAV(id,c,cfg);

                    obj.clusters(c).addUAV(u);

                    id = id + 1;

                end

            end

            % First UAV is the Swarm Leader
            obj.leader = obj.clusters(1).head;

            %Initialize it after creating the initial swarm:
            obj.nextUAVID = cfg.numUAVs + 1;

            engine = SBPEngine(cfg);

            for c = 1:length(obj.clusters)

                obj.clusters(c).groupKey = ...
                    engine.generateGroupKey(obj.clusters(c).uavs);

            end

        end

        %------------------------------------------

        function uav = addUAV(obj, uavID, clusterID)

            % Create UAV
            uav = UAV(uavID, clusterID, obj.config);

            % Add UAV to the selected cluster
            obj.clusters(clusterID).addUAV(uav);

        end

        %------------------------------------------
        function removeUAV(obj, uavID)

            for i = 1:length(obj.clusters)

                if obj.clusters(i).removeUAV(uavID)

                    return;

                end

            end

        end



        function n = totalUAVs(obj)

            n = 0;

            for i = 1:length(obj.clusters)
                n = n + obj.clusters(i).count();
            end

        end

        %------------------------------------------

        function active = activeUAVs(obj)

            active = 0;

            for i = 1:length(obj.clusters)

                active = active + ...
                    length(obj.clusters(i).getActiveUAVs());

            end

        end
        %------------------------------------------
        function uavs = getActiveUAVs(obj)

            uavs = UAV.empty;

            for i = 1:length(obj.clusters)

                uavs = [uavs obj.clusters(i).getActiveUAVs()];

            end

        end


        %------------------------------------------

        function uav = findUAV(obj,id)

            uav = [];

            for c = 1:length(obj.clusters)

                for k = 1:length(obj.clusters(c).uavs)

                    if obj.clusters(c).uavs(k).id == id

                        uav = obj.clusters(c).uavs(k);
                        return

                    end

                end

            end

        end

        function step(obj,cfg)

            for c = 1:length(obj.clusters)

                cluster = obj.clusters(c);

                for i = 1:cluster.count()

                    u = cluster.uavs(i);

                    if ~u.active
                        continue
                    end

                    % Physical movement
                    u.move(cfg.timeStep);

                    % Energy consumption
                    u.consumeEnergy(0.05);

                    % DT update
                    u.dt.tick(u,cfg);

                end

            end

        end

        function id = allocateUAVID(obj)

            id = obj.nextUAVID;

            obj.nextUAVID = obj.nextUAVID + 1;

        end


        function uav = getRandomActiveUAV(obj)

            activeUAVs = UAV.empty;

            for i = 1:length(obj.clusters)

                activeUAVs = [activeUAVs obj.clusters(i).getActiveUAVs()];

            end

            if isempty(activeUAVs)

                uav = [];

                return;

            end

            index = randi(numel(activeUAVs));

            uav = activeUAVs(index);

        end


    end

end