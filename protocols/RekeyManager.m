classdef RekeyManager < handle

    properties (Access = private)

        cfg

        totalRekeys = 0

    end

    methods

        function obj = RekeyManager(cfg)

            obj.cfg = cfg;

        end

        %----------------------------------------------------------
        function performLocalRekey(obj, cluster)

            obj.totalRekeys = obj.totalRekeys + 1;

        end

        %----------------------------------------------------------
        function n = getTotalRekeys(obj)

            n = obj.totalRekeys;

        end

    end

end