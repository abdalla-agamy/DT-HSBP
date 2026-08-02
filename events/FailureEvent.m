classdef FailureEvent < Event

    properties (SetAccess = private)

        uavID   double
        reason  string

    end

    methods

        function obj = FailureEvent(time, uavID, reason)

            obj@Event(time, "Failure");

            obj.uavID  = uavID;
            obj.reason = reason;

        end

        function execute(obj, simulation)

            simulation.failUAV(obj.uavID, obj.reason);

        end

    end

end