classdef DTAgent < handle

    properties

        state
        predictedState

        residual
        stabilityScore

    end

    methods

        function obj = DTAgent()

            obj.residual = 0;
            obj.stabilityScore = 0;

        end

        function update(obj,uav,cfg)

            actual = DTState(uav);

            obj.predictedState = ...
                Predictor.predict(obj.state,...
                cfg.predictionHorizon);

            obj.residual = ...
                Residual.compute(actual,...
                obj.predictedState);

            obj.stabilityScore = ...
                StabilityModel.compute(obj.residual);

            obj.state = actual;

        end

        %---------------------------------------

        function observe(obj,uav)

            x= DTState(uav);
            obj.state =x;

        end

    end

end