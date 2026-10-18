classdef UAV < handle

    properties
        % Identity
        id
        clusterID

        % Cryptography
        privateKey
        groupKey

        % Physical State
        position        % [x y]
        velocity        % [vx vy]
        energy
        linkQuality

        % DT State
        keySynced
        stabilityScore
        estimatedLifespan   % L_i(t) = E_i(t) / energyConsumptionRate

        % Membership
        active

        dt
    end

    methods

        function obj = UAV(id, clusterID, cfg)

            obj.id = id;
            obj.clusterID = clusterID;

            % Random private exponent
            obj.privateKey = randi([2 100000]);

            obj.groupKey = [];

            % Random initial position
            obj.position = [
                rand()*cfg.areaX,...
                rand()*cfg.areaY];

            % Random velocity
            obj.velocity = [
                rand()*cfg.maxVelocity,...
                rand()*cfg.maxVelocity];

            obj.energy = 100;
            obj.linkQuality = 1.0;

            obj.keySynced = true;
            obj.stabilityScore = 0;

            rate = 0.1;
            if nargin >= 3 && isfield(cfg, 'energyConsumptionRate') && cfg.energyConsumptionRate > 0
                rate = cfg.energyConsumptionRate;
            end
            obj.estimatedLifespan = obj.energy / rate;

            obj.active = true;

            obj.dt = DTAgent(obj,cfg);

            obj.dt.observe(obj);

        end

        %---------------------------------------------

        function move(obj,cfg)

            obj.position = obj.position + ...
                obj.velocity*cfg.timeStep;

        end

        %---------------------------------------------

        function consumeEnergy(obj, amount)

            rate = 0.1;
            if ~isempty(obj.dt) && isfield(obj.dt.cfg, 'energyConsumptionRate') && obj.dt.cfg.energyConsumptionRate > 0
                rate = obj.dt.cfg.energyConsumptionRate;
            end

            if nargin < 2 || isempty(amount)
                amount = rate;
            end

            obj.energy = max(0, obj.energy - amount);
            if rate > 0
                obj.estimatedLifespan = obj.energy / rate;
            end
            if ~isempty(obj.dt)
                obj.dt.estimatedLifespan = obj.estimatedLifespan;
            end

        end

        %---------------------------------------------

        function L = getEstimatedLifespan(obj, rate)

            if nargin < 2 || isempty(rate)
                rate = 0.1;
                if ~isempty(obj.dt) && isfield(obj.dt.cfg, 'energyConsumptionRate') && obj.dt.cfg.energyConsumptionRate > 0
                    rate = obj.dt.cfg.energyConsumptionRate;
                end
            end
            if rate <= 0
                rate = 0.1;
            end
            obj.estimatedLifespan = obj.energy / rate;
            L = obj.estimatedLifespan;

        end

        %---------------------------------------------

        function S = getStabilityScore(obj)

            if ~isempty(obj.dt)
                obj.stabilityScore = obj.dt.stabilityScore;
            end
            S = obj.stabilityScore;

        end

        %---------------------------------------------

        function degradeLink(obj)

            obj.linkQuality = max(0,...
                obj.linkQuality-0.001*rand());

        end

        %---------------------------------------------

        function fail(obj)

            obj.active = false;

        end

    end

end