classdef JoinEvent < events.Event

    properties (SetAccess = private)

        uavID      double
        clusterID  double

    end

    methods

        function obj = JoinEvent(time, uavID, clusterID)

            obj@events.Event(time, "Join");

            obj.uavID = uavID;
            obj.clusterID = clusterID;

        end

        function execute(obj, simulation)

            simulation.addUAV(obj.uavID, obj.clusterID);

        end

    end

end