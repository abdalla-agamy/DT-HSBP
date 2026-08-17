classdef Cluster < handle

    properties
        id
        head            % Cluster Head (UAV object)
        uavs            % Array of UAV objects
        groupKey

        % Cached active members. This cache mirrors the membership of uavs
        % and avoids rebuilding a temporary UAV array for every rekey.
        activeUAVsCache
    end

    methods

        %----------------------------------------------

        function obj = Cluster(id)
            obj.id = id;
            obj.uavs = UAV.empty;
            obj.head = [];
            obj.groupKey = [];
            obj.activeUAVsCache = UAV.empty;
        end

        %----------------------------------------------

        function addUAV(obj,uav)

            obj.uavs(end+1) = uav;

            % First UAV becomes Cluster Head
            if isempty(obj.head)
                obj.head = uav;
            end

            % Membership is active when a UAV is added to the cluster.
            obj.activeUAVsCache(end+1) = uav;

        end

        %----------------------------------------------

        function removed = removeUAV(obj, uavID)

            removed = false;

            for i = 1:length(obj.uavs)

                if obj.uavs(i).id == uavID

                    wasHead = ~isempty(obj.head) && ...
                        obj.head.id == uavID;

                    obj.uavs(i) = [];

                    % Remove the same UAV from the cached active list.
                    for j = 1:length(obj.activeUAVsCache)
                        if obj.activeUAVsCache(j).id == uavID
                            obj.activeUAVsCache(j) = [];
                            break;
                        end
                    end

                    if wasHead

                        if isempty(obj.uavs)

                            obj.head = [];

                        else

                            obj.head = obj.uavs(1);

                        end

                    end

                    removed = true;

                    return;

                end

            end

        end

        %----------------------------------------------

        function list = getActiveUAVs(obj)

            % Return the cached active-member array. Membership changes are
            % handled by addUAV/removeUAV, so no temporary array needs to be
            % rebuilt for each caller.
            list = obj.activeUAVsCache;

        end

        %----------------------------------------------

        function n = count(obj)
            n = length(obj.uavs);
        end

    end
end
