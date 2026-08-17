classdef DTPredictedDepartureEvent < handle
    %DTPREDICTEDDEPARTUREEVENT Materialize a persistent DT prediction.
    %
    % This event is intentionally separate from the exogenous Poisson
    % membership events. It represents a departure that was predicted by
    % the DT and has subsequently been realized by the stochastic DT-aware
    % departure model.

    properties
        time
        uavID
        reason
    end

    methods
        function obj = DTPredictedDepartureEvent(time, uavID, reason)
            obj.time = time;
            obj.uavID = uavID;
            if nargin < 3 || isempty(reason)
                reason = "DT-predicted instability";
            end
            obj.reason = string(reason);
        end

        function execute(obj, simulation)
            uav = simulation.swarm.findUAV(obj.uavID);
            if isempty(uav) || ~uav.active
                return;
            end

            % The DT prediction has already identified this UAV as an
            % imminent departure. The normal DTHSBP protocol path performs
            % the cluster-local batch rekey when this departure is handled.
            simulation.processPredictedDeparture(obj.uavID, obj.reason);
        end
    end
end
