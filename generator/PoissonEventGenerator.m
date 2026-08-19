classdef PoissonEventGenerator < handle

    properties (Access = private)

        cfg
        stepIndex = 0

    end

    methods

        function obj = PoissonEventGenerator(cfg)

            obj.cfg = cfg;

        end

        function eventCounts = generate(obj)

            % Mean number of events during one simulation step.
            muJoin    = obj.cfg.joinRate    * obj.cfg.timeStep;
            muLeave   = obj.cfg.leaveRate   * obj.cfg.timeStep;
            muFailure = obj.cfg.failureRate * obj.cfg.timeStep;

            % The membership workload is an exogenous stochastic input.
            % Generate it from a deterministic per-run/per-step substream so
            % protocol-specific random draws cannot change later workloads.
            obj.stepIndex = obj.stepIndex + 1;
            workloadSeed = obj.deriveSeed(obj.cfg.randomSeed, obj.stepIndex, 1000003);

            previousState = rng;
            cleanup = onCleanup(@() rng(previousState)); %#ok<NASGU>
            rng(workloadSeed);

            eventCounts.join    = poissrnd(muJoin);
            eventCounts.leave   = poissrnd(muLeave);
            eventCounts.failure = poissrnd(muFailure);

        end

    end

    methods (Access = private)

        function seed = deriveSeed(~, baseSeed, stepIndex, multiplier)
            modulus = 4294967291;
            seed = mod(double(baseSeed) + double(stepIndex) * multiplier, modulus);
            seed = floor(seed);
        end

    end

end