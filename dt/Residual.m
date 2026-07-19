classdef Residual

    methods (Static)

        function r = compute(actual,predicted)

            dp = norm(actual.position - predicted.position);

            dv = norm(actual.velocity - predicted.velocity);

            de = abs(actual.energy - predicted.energy);

            dl = abs(actual.linkQuality - predicted.linkQuality);

            dk = double(actual.keySynced ~= predicted.keySynced);

            r = sqrt( ...
                dp^2 + ...
                dv^2 + ...
                de^2 + ...
                dl^2 + ...
                dk^2);

        end

    end

end