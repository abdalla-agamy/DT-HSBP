classdef (Abstract) Event < handle

    properties (SetAccess = protected)

        time    double
        type    string

    end

    methods

        function obj = Event(time, type)

            obj.time = time;
            obj.type = type;

        end

    end

    methods (Abstract)

        execute(obj, simulation)

    end

end