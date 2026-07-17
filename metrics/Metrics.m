classdef Metrics < handle

    properties

        communication = 0;
        computation   = 0;

        joins   = 0;
        leaves  = 0;
        failures = 0;

    end

    methods

        function reset(obj)

            obj.communication = 0;
            obj.computation = 0;

            obj.joins = 0;
            obj.leaves = 0;
            obj.failures = 0;

        end

        %----------------------------------------

        function addCommunication(obj,value)

            obj.communication = ...
                obj.communication + value;

        end

        %----------------------------------------

        function addComputation(obj,value)

            obj.computation = ...
                obj.computation + value;

        end

        %----------------------------------------

        function report(obj)

            fprintf("\n");
            fprintf("Communication : %d\n",obj.communication);
            fprintf("Computation   : %d\n",obj.computation);
            fprintf("Join Events   : %d\n",obj.joins);
            fprintf("Leave Events  : %d\n",obj.leaves);
            fprintf("Failures      : %d\n",obj.failures);

        end

    end

end