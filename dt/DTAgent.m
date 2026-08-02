classdef DTAgent < handle

    properties

        state
        predictedState

        residual
        stabilityScore


        initialized = false;
        %hasPrediction = false;

        uav
        cfg


    end

    methods

        function obj = DTAgent(uav, cfg)

            obj.uav = uav;
            obj.cfg = cfg;

            obj.residual = 0;
            obj.stabilityScore = 0;

        end

        %---------------------------------------

        function update(obj)

            if isempty(obj.predictedState)

                obj.observe();

                obj.predictedState = ...
                    Predictor.predict(obj.state,...
                    obj.cfg.predictionHorizon);

                return

            end

            actual = DTState(obj.uav);

            obj.residual = ...
                Residual.compute(actual,...
                obj.predictedState);

            obj.stabilityScore = ...
                StabilityModel.compute(obj.residual);

            obj.state = actual;

            obj.predictedState = ...
                Predictor.predict(actual,...
                obj.cfg.predictionHorizon);

        end


        function observe(obj,uav)

           obj.state = DTState(obj.uav);

           obj.initialized = true;
        end

        function stable = isStable(obj,cfg)

            stable = StabilityModel.isStable( ...
                obj.stabilityScore, ...
                obj.cfg);


        end

    end

end