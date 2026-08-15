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

        function result = join(obj,uavID,clusterID)

            obj.swarm.addUAV(uavID,clusterID);

            allUAVs = obj.swarm.getActiveUAVs();

            newGroupKey = obj.engine.generateGroupKey(allUAVs);

            for i = 1:numel(allUAVs)

                allUAVs(i).groupKey = newGroupKey;
                allUAVs(i).keySynced = true;

            end

            result = obj.createRekeyResult(allUAVs,[]);

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordJoin();

        end

        %-----------------------------------

        function result = leave(obj,uavID)

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)
                result = [];
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

                result = obj.createRekeyResult(allUAVs,[]);

            else

                result = [];

            end

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordLeave();

        end

        %-----------------------------------

        function result = failure(obj,uavID)

            uav = obj.swarm.findUAV(uavID);

            if isempty(uav)
                result = [];
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

                result = obj.createRekeyResult(allUAVs,[]);

            else

                result = [];

            end

            obj.addCost(obj.swarm.totalUAVs());

            obj.recordFailure();

        end

    end

end