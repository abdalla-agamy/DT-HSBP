classdef LeaveEvent < Event

    properties (SetAccess = private)

        uavID      double
        clusterID  double

    end

    methods

        function obj = LeaveEvent(time, uavID, clusterID)

            obj@Event(time, "Leave");

            obj.uavID = uavID;
            obj.clusterID = clusterID;

        end

        function execute(obj, simulation)

            simulation.processLeaveRequest(obj.uavID);

        end

    end

end