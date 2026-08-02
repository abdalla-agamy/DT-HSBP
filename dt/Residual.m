classdef Residual

    methods (Static)

        function r = compute(actual,predicted, cfg)

            dp = norm(actual.position - predicted.position);

            dv = norm(actual.velocity - predicted.velocity);

            de = abs(actual.energy - predicted.energy);

            dl = abs(actual.linkQuality - predicted.linkQuality);

            dk = double(actual.keySynced ~= predicted.keySynced);

            r = sqrt( ...
                cfg.residualWeights.position    * dp^2 + ...
                cfg.residualWeights.velocity    * dv^2 + ...
                cfg.residualWeights.energy      * de^2 + ...
                cfg.residualWeights.linkQuality * dl^2 + ...
                cfg.residualWeights.keySynced   * dk^2);

        end

    end

end