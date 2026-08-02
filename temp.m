classdef temp < handle
    properties
        cfg
        agents = DTAgent.empty;

    end

    methods
        function obj = temp(cfg)
            obj.cfg = cfg;
        end
    end
end