classdef DTDisturbanceGenerator < handle
%DTDISTURBANCEGENERATOR Generate stochastic physical DT disturbances.
%
%   This generator is independent of Join/Leave/Failure membership events.
%   It samples the number of disturbances during each simulation step from
%   a Poisson process with rate cfg.dtDisturbanceRate.

    properties (Access = private)
        cfg
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
            disturbanceCount = poissrnd(mu);
        end
    end
end
