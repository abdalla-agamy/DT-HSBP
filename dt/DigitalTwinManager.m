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
            %REGISTERUAV Register the Digital Twin owned by the UAV.

            if ~isempty(obj.findAgent(uav.id))
                return;
            end

            obj.agents(end+1) = uav.dt;

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
        function candidates = findUnstableUAVs(obj, excludedIDs)

            %FINDUNSTABLEUAVS Return UAV IDs predicted to become unstable.

            if nargin < 2
                excludedIDs = [];
            end
            candidates = [];

            for i = 1:numel(obj.agents)

                id = obj.agents(i).uav.id;

                if ismember(id, excludedIDs)
                    continue;
                end

                if StabilityModel.shouldLeave( ...
                        obj.agents(i).residual, ...
                        obj.cfg)

                    candidates(end+1) = id;

                end

            end
            

        end
        %----------------------------------------------------------

        function n = count(obj)

            n = numel(obj.agents);

        end

    end

end