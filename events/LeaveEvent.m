classdef LeaveEvent

    methods(Static)

        function execute(swarm, uavID)

            for c = 1:length(swarm.clusters)

                cluster = swarm.clusters(c);

                for k = 1:length(cluster.uavs)

                    if cluster.uavs(k).id == uavID

                        cluster.removeUAV(uavID);
                        return;

                    end

                end

            end

        end

    end

end