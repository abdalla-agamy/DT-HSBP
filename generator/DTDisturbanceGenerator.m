classdef DTDisturbanceGenerator < handle
%DTDISTURBANCEGENERATOR Generate stochastic physical DT disturbances.
%
%   This generator is independent of Join/Leave/Failure membership events.
%   It samples the number of disturbances during each simulation step from
%   a Poisson process with rate cfg.dtDisturbanceRate.

    properties (Access = private)
        cfg
        stepIndex = 0
    end

    methods
        function obj = DTDisturbanceGenerator(cfg)
            obj.cfg = cfg;
        end

        function disturbanceCount = generate(obj)
            if ~isfield(obj.cfg,'dtDisturbanceEnabled') || ...
                    ~obj.cfg.dtDisturbanceEnabled
                disturbanceCount = 0;
                return;
            end

            validateattributes(obj.cfg.dtDisturbanceRate, ...
                {'numeric'}, {'scalar','real','finite','nonnegative'});

            mu = obj.cfg.dtDisturbanceRate * obj.cfg.timeStep;

            % Keep the exogenous DT disturbance workload independent of
            % protocol-specific random draws and of membership-event draws.
            obj.stepIndex = obj.stepIndex + 1;
            disturbanceSeed = obj.deriveSeed( ...
                obj.cfg.randomSeed, obj.stepIndex, 2000003);

            previousState = rng;
            cleanup = onCleanup(@() rng(previousState)); %#ok<NASGU>
            rng(disturbanceSeed);

            disturbanceCount = poissrnd(mu);
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