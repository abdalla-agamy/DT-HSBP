classdef DigitalTwinManager < handle

    properties (Access = private)

        cfg

        agents DTAgent = DTAgent.empty;

    end

    methods

        function obj = DigitalTwinManager(cfg)

            obj.cfg = cfg;

        end

        %----------------------------------------------------------
        function registerUAV(obj, uav)

            agent = DTAgent(uav, obj.cfg);

            obj.agents(end+1) = agent;

        end

        %----------------------------------------------------------
        function removeUAV(obj, uavID)

            for i = 1:numel(obj.agents)

                if obj.agents(i).uav.id == uavID

                    obj.agents(i) = [];

                    return;

                end

            end

        end

        %----------------------------------------------------------
        function update(obj)

            for i = 1:numel(obj.agents)

                obj.agents(i).update();

            end

        end

        %----------------------------------------------------------
        function n = count(obj)

            n = numel(obj.agents);

        end

    end

end