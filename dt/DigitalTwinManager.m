classdef DigitalTwinManager < handle

    properties (Access = private)

        cfg

        agents  = DTAgent.empty;

    end

    methods

        function obj = DigitalTwinManager(cfg)

            obj.cfg = cfg;

        end

        %----------------------------------------------------------
        function registerUAV(obj, uav)
            %REGISTERUAV Create a Digital Twin for a UAV.

            agent = DTAgent(uav, obj.cfg);

            obj.agents(end+1) = agent;

        end

        %----------------------------------------------------------
        function removeUAV(obj, uavID)
            %REMOVEUAV Remove the Digital Twin associated with a UAV.

            for i = 1:numel(obj.agents)

                if obj.agents(i).uav.id == uavID

                    obj.agents(i) = [];

                    return;

                end

            end

        end

        %----------------------------------------------------------
        function update(obj)
            %UPDATE Update all Digital Twins.

            for i = 1:numel(obj.agents)

                obj.agents(i).update();

            end

        end

        %----------------------------------------------------------
        function agent = findAgent(obj, uavID)

            %FINDAGENT Return the DTAgent corresponding to a UAV.

            agent = [];

            for i = 1:numel(obj.agents)

                if obj.agents(i).uav.id == uavID

                    agent = obj.agents(i);

                    return;

                end

            end

        end
        %----------------------------------------------------------
        function n = count(obj)

            n = numel(obj.agents);

        end

    end

end