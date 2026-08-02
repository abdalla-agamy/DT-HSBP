classdef StabilityModel

    methods (Static)

        function score = compute(residual)

            score = exp(-residual);

        end

        %----------------------------

        function stable = isStable(score,cfg)

            stable = score < cfg.stabilityThreshold;

        end

    end

end