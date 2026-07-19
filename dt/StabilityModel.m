classdef StabilityModel

    methods (Static)

        function score = compute(residual)

            score = residual;

        end

        %----------------------------

        function stable = isStable(score,cfg)

            stable = score < cfg.thetaLeave;

        end

    end

end