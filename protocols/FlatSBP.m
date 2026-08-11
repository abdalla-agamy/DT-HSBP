classdef FlatSBP < Protocol

    methods

        function obj = FlatSBP(swarm)

            obj@Protocol(swarm);

        end

        %-----------------------------------

        function initialize(obj)

            fprintf("FlatSBP initialized\n");

        end

        %-----------------------------------

        function join(obj,clusterID)

            uavID = obj.swarm.allocateUAVID();

            obj.swarm.addUAV(uavID,clusterID);

            allUAVs = obj.swarm.getActiveUAVs();

            newGroupKey = obj.engine.generateGroupKey(allUAVs);

            for i = 1:numel(allUAVs)

                allUAVs(i).groupKey = newGroupKey;
                allUAVs(i).keySynced = true;

            end

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordJoin();

        end

        %-----------------------------------

        function leave(obj,uavID)

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)
                return;
            end

            obj.swarm.removeUAV(uavID);

            allUAVs = obj.swarm.getActiveUAVs();

            if ~isempty(allUAVs)

                newGroupKey = obj.engine.generateGroupKey(allUAVs);

                for i = 1:numel(allUAVs)

                    allUAVs(i).groupKey = newGroupKey;
                    allUAVs(i).keySynced = true;

                end

            end

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordLeave();

        end

        %-----------------------------------

        function failure(obj,uavID)

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)
                return;
            end

            obj.swarm.removeUAV(uavID);

            allUAVs = obj.swarm.getActiveUAVs();

            if ~isempty(allUAVs)

                newGroupKey = obj.engine.generateGroupKey(allUAVs);

                for i = 1:numel(allUAVs)

                    allUAVs(i).groupKey = newGroupKey;
                    allUAVs(i).keySynced = true;

                end

            end

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordFailure();

        end

    end

end