classdef DTAgent < handle

    properties

        state
        predictedState

        residual
        stabilityScore


        initialized = false;
        hasPrediction = false;


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

        function tick(obj,uav,cfg)

            if isempty(obj.predictedState)

                obj.observe(uav);

                obj.predictedState = ...
                    Predictor.predict(obj.state,...
                    cfg.predictionHorizon);

                return

            end

            actual = DTState(uav);

            obj.residual = ...
                Residual.compute(actual,...
                obj.predictedState);

            obj.stabilityScore = ...
                StabilityModel.compute(obj.residual);

            obj.state = actual;

            obj.predictedState = ...
                Predictor.predict(actual,...
                cfg.predictionHorizon);

        end


        function observe(obj,uav)

            x= DTState(uav);
            obj.state =x;

            if ~obj.initialized
                obj.initialized = true;
            end
        end
        function stable = isStable(obj,cfg)

            stable = StabilityModel.isStable(...
                obj.stabilityScore,cfg);

        end

    end

end