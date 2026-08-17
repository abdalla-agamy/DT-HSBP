classdef DTDisturbanceEvent < handle
    %DTDISTURBANCEEVENT Physical disturbance applied to selected UAVs.
    %
    % The disturbance is deliberately not a membership event. It changes
    % physical UAV state and lets the normal DT lifecycle detect the
    % resulting prediction residual.

    properties
        time
        clusterID
        uavIDs
        positionDelta
        velocityDelta
        energyDrop
    end

    methods
        function obj = DTDisturbanceEvent(time, clusterID, uavIDs, ...
                positionDelta, velocityDelta, energyDrop)
            obj.time = time;
            obj.clusterID = clusterID;
            obj.uavIDs = uavIDs(:).';
            obj.positionDelta = positionDelta;
            obj.velocityDelta = velocityDelta;
            obj.energyDrop = energyDrop;
        end

        function execute(obj, simulation)
            % Apply the physical disturbance only. No membership change and
            % no rekey occur here. The subsequent physical/DT lifecycle
            % detects the instability.
            for i = 1:numel(obj.uavIDs)
                uav = simulation.swarm.findUAV(obj.uavIDs(i));
                if isempty(uav)
                    continue;
                end

                if ~isempty(obj.positionDelta)
                    uav.position = uav.position + obj.positionDelta;
                end

                if ~isempty(obj.velocityDelta)
                    uav.velocity = uav.velocity + obj.velocityDelta;
                end

                if obj.energyDrop ~= 0
                    uav.energy = max(0, uav.energy - obj.energyDrop);
                end
            end
        end
    end
end
