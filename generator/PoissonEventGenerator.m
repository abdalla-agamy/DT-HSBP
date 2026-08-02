classdef PoissonEventGenerator < handle

    properties (Access = private)

        cfg

    end

    methods

        function obj = PoissonEventGenerator(cfg)

            obj.cfg = cfg;

        end

        function eventCounts = generate(obj)


            % Mean number of events during one simulation step
            muJoin    = obj.cfg.joinRate    * obj.cfg.timeStep;
            muLeave   = obj.cfg.leaveRate   * obj.cfg.timeStep;
            muFailure = obj.cfg.failureRate * obj.cfg.timeStep;

            % Generate the number of events
            eventCounts.join    = poissrnd(muJoin);
            eventCounts.leave   = poissrnd(muLeave);
            eventCounts.failure = poissrnd(muFailure);

        end

    end

end