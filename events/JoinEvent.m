classdef JoinEvent

    methods(Static)

        function execute(swarm, clusterID)

            cfg = swarm.config;

            % Determine next available ID
            newID = swarm.nextUAVID;
            swarm.nextUAVID = swarm.nextUAVID + 1;

            % Create UAV
            u = UAV(newID, clusterID, cfg);

            % Add to cluster
            swarm.clusters(clusterID).addUAV(u);

        end

    end

end