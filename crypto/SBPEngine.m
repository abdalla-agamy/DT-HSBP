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

        function key = generateGroupKey(obj,uavs)

            value = obj.g;

            for i = 1:length(uavs)

                value = powermod( ...
                    value,...
                    uavs(i).privateKey,...
                    obj.p);

            end

            key = value;

        end

    end

end