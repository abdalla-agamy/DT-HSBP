classdef DTAgent < handle

    properties

        state
        predictedState

        residual
        stabilityScore

        predictedLeave = false
        predictionTime = NaN
        predictionExpiry = NaN

        initialized = false

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

        function update(obj)

            if isempty(obj.predictedState)
                obj.observe(obj.uav);

                obj.predictedState = ...
                    Predictor.predict(obj.state, ...
                    obj.cfg.predictionHorizon, obj.cfg);

                obj.clearExpiredPrediction(obj.getCurrentTime());
                return
            end

            actual = DTState(obj.uav);

            obj.residual = Residual.compute( ...
                actual, obj.predictedState, obj.cfg);

            obj.stabilityScore = obj.residual;
            obj.state = actual;

            currentTime = obj.getCurrentTime();

            if StabilityModel.shouldLeave( ...
                    obj.stabilityScore, obj.cfg)
                obj.predictedLeave = true;
                obj.predictionTime = currentTime;
                obj.predictionExpiry = ...
                    currentTime + obj.cfg.predictionHorizon;
            elseif ~obj.predictedLeave
                obj.predictionTime = NaN;
                obj.predictionExpiry = NaN;
            else
                obj.clearExpiredPrediction(currentTime);
            end

            obj.predictedState = Predictor.predict( ...
                actual, obj.cfg.predictionHorizon, obj.cfg);
        end

        function observe(obj, uav)
            if nargin < 2 || isempty(uav)
                uav = obj.uav;
            end
            obj.state = DTState(uav);
            obj.initialized = true;
        end

        function stable = isStable(obj)
            stable = StabilityModel.isStable( ...
                obj.stabilityScore, obj.cfg);
        end

        function tf = hasPredictedLeave(obj,currentTime)
            if nargin < 2
                currentTime = obj.getCurrentTime();
            end
            obj.clearExpiredPrediction(currentTime);
            tf = obj.predictedLeave;
        end

        function consumePrediction(obj)
            obj.predictedLeave = false;
            obj.predictionTime = NaN;
            obj.predictionExpiry = NaN;
        end

        function cancelPrediction(obj)
            obj.consumePrediction();
        end
    end

    methods (Access = private)
        function t = getCurrentTime(obj)
            if isfield(obj.cfg,'currentTime')
                t = obj.cfg.currentTime;
            else
                t = 0;
            end
        end

        function clearExpiredPrediction(obj,currentTime)
            if obj.predictedLeave && ...
                    ~isnan(obj.predictionExpiry) && ...
                    currentTime > obj.predictionExpiry
                obj.consumePrediction();
            end
        end
    end

end
