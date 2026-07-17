classdef FailureEvent

    methods(Static)

        function execute(swarm,uavID)

            u = swarm.findUAV(uavID);

            if ~isempty(u)
                u.fail();
            end

        end

    end

end