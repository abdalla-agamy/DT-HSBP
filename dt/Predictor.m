classdef Predictor

    methods (Static)

        function predicted = predict(state, dt, cfg)

            predicted = state;

            % Constant velocity prediction
            predicted.position = ...
                state.position + state.velocity * dt;

            % Energy consumption model
            predicted.energy = ...
                max(0, state.energy - cfg.energyConsumptionRate * dt);

            % Link quality assumed unchanged
            predicted.linkQuality = state.linkQuality;

            % Key synchronization unchanged
            predicted.keySynced = state.keySynced;

        end

    end

end