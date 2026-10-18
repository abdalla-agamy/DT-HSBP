classdef SBPEngine < handle

    properties

        g
        p

    end

    methods

        function obj = SBPEngine(cfg)

            obj.g = cfg.generator;
            obj.p = cfg.prime;

        end

        %----------------------------------------

        function [key, intermediateChain] = generateGroupKey(obj,uavs)

            value = obj.g;
            intermediateChain = zeros(1, length(uavs));

            for i = 1:length(uavs)

                value = powermod( ...
                    value,...
                    uavs(i).privateKey,...
                    obj.p);
                intermediateChain(i) = value;

            end

            key = value;

        end

    end

end