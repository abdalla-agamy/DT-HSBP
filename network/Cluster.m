classdef Cluster < handle

    properties
        id
        head            % Cluster Head (UAV object)
        uavs            % Array of UAV objects
        groupKey
    end

    methods

        function obj = Cluster(id)
            obj.id = id;
            obj.uavs = UAV.empty;
            obj.head = [];
        end

        %----------------------------------------------

        function addUAV(obj,uav)

            obj.uavs(end+1) = uav;

            % First UAV becomes Cluster Head
            if isempty(obj.head)
                obj.head = uav;
            end

        end

        %----------------------------------------------

        function removed = removeUAV(obj, uavID)

            removed = false;

            for i = 1:length(obj.members)

                if obj.uavs(i).id == uavID

                    obj.uavs(i) = [];

                    removed = true;

                    return;

                end

            end

        end

        %----------------------------------------------

        function list = getActiveUAVs(obj)

            list = UAV.empty;

            for i = 1:length(obj.uavs)

                if obj.uavs(i).active
                    list(end+1) = obj.uavs(i);
                end

            end

        end

        %----------------------------------------------

        function n = count(obj)

            n = length(obj.uavs);

        end

    end

end