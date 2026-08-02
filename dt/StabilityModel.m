classdef StabilityModel

    methods (Static)

        function tf = canJoin(Di, cfg)

            tf = Di < cfg.thetaJoin;

        end

        %----------------------------------------------------------

        function tf = shouldLeave(Di, cfg)

            tf = Di > cfg.thetaLeave;

        end

        %----------------------------------------------------------

        function tf = isClusterUnstable(clusterDeviation, cfg)

            tf = clusterDeviation > cfg.thetaCluster;

        end

        %----------------------------

        function stable = isStable(score,cfg)

            stable = score < cfg.stabilityThreshold;

        end

    end

end