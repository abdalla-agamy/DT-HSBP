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

        function removeUAV(obj,uavID)

            idx = [];

            for i = 1:length(obj.uavs)

                if obj.uavs(i).id == uavID
                    idx = i;
                    break;
                end

            end

            if ~isempty(idx)

                removedHead = isequal(obj.uavs(idx),obj.head);

                obj.uavs(idx) = [];

                if removedHead

                    if isempty(obj.uavs)
                        obj.head = [];
                    else
                        obj.head = obj.uavs(1);
                    end

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