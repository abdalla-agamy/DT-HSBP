classdef Cluster < handle

    properties
        id
        head            % Cluster Head (UAV object)
        uavs            % Array of UAV objects
        groupKey
        precomputedKeyCache = []   % Cache for precomputed key packages (Contribution B)
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

            for i = 1:length(obj.uavs)

                if obj.uavs(i).id == uavID

                    obj.uavs(i).active = false;

                    wasHead = ~isempty(obj.head) && ...
                        obj.head.id == uavID;

                    obj.uavs(i) = [];

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

            list = UAV.empty;

            for i = 1:length(obj.uavs)

                if obj.uavs(i).active
                    list(end+1) = obj.uavs(i);
                end

            end

        end

        %----------------------------------------------

        function [sortedList, sortKeys] = getSortedActiveUAVs(obj, w1, w2)

            list = obj.getActiveUAVs();

            if isempty(list)
                sortedList = UAV.empty;
                sortKeys = [];
                return;
            end

            if nargin < 2 || isempty(w1)
                w1 = 1.0;
                if ~isempty(list(1).dt) && isfield(list(1).dt.cfg, 'sortWeightEnergy')
                    w1 = list(1).dt.cfg.sortWeightEnergy;
                end
            end

            if nargin < 3 || isempty(w2)
                w2 = 1.0;
                if ~isempty(list(1).dt) && isfield(list(1).dt.cfg, 'sortWeightStability')
                    w2 = list(1).dt.cfg.sortWeightStability;
                end
            end

            n = numel(list);
            sortKeys = zeros(1, n);

            for i = 1:n
                u = list(i);
                e = u.energy;
                s = u.stabilityScore;
                if ~isempty(u.dt)
                    s = u.dt.stabilityScore;
                    u.stabilityScore = s;
                end
                sortKeys(i) = w1 * e - w2 * s;
            end

            % High battery and high stability come first (descending sort)
            % Depleted / unstable nodes placed at tail (k -> nc)
            [sortKeys, sortIdx] = sort(sortKeys, 'descend');
            sortedList = list(sortIdx);

        end

        %----------------------------------------------

        function n = count(obj)

            n = length(obj.uavs);

        end

        %----------------------------------------------

        function setPrecomputedKey(obj, package)
            obj.precomputedKeyCache = package;
        end

        %----------------------------------------------

        function pkg = getPrecomputedKey(obj, departingIDs)
            pkg = [];
            if isempty(obj.precomputedKeyCache)
                return;
            end
            if nargin < 2 || isempty(departingIDs)
                pkg = obj.precomputedKeyCache;
                return;
            end
            if isfield(obj.precomputedKeyCache, 'departingIDs')
                cachedIDs = sort(obj.precomputedKeyCache.departingIDs);
                queryIDs = sort(departingIDs);
                if isequal(cachedIDs, queryIDs) || all(ismember(queryIDs, cachedIDs))
                    pkg = obj.precomputedKeyCache;
                end
            else
                pkg = obj.precomputedKeyCache;
            end
        end

        %----------------------------------------------

        function clearPrecomputedKey(obj)
            obj.precomputedKeyCache = [];
        end

    end

end
