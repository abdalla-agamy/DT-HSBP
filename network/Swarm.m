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

        end

        %------------------------------------------

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

    end

end