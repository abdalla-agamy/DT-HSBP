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

            obj.active = true;

            obj.dt = DTAgent();

            obj.dt.observe(obj);

        end

        %---------------------------------------------

        function move(obj,cfg)

            obj.position = obj.position + ...
                obj.velocity*cfg.timeStep;

        end

        %---------------------------------------------

        function consumeEnergy(obj)

            obj.energy = max(0,obj.energy-0.1);

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