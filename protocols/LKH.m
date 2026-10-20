classdef LKH < Protocol
    %LKH Logical Key Hierarchy (LKH) Group Key Management Protocol
    % Implements the canonical tree-based key management protocol (Wong et al., IEEE/ACM ToN 2000).
    % Each cluster maintains a balanced d-ary logical tree (default d=2, binary tree).
    % Root key = Group session key.
    % Leaf nodes = Individual UAV private keys.
    % Internal nodes = Key-Encrypting Keys (KEKs).
    % Member storage overhead = O(log_d n_c) keys per member.
    % Leave communication overhead = O(d * log_d n_c) encrypted keys.
    % Batch leave communication overhead = O(B * log_d(n_c / B)) encrypted keys.

    properties
        treeDegree = 2;          % Binary tree by default (d = 2)
        keySizeBytes = 32;       % 256-bit symmetric key (AES-256)
        clusterTrees             % Map of clusterID -> Tree structure
    end

    methods
        function obj = LKH(swarm, degree)
            obj@Protocol(swarm);
            if nargin >= 2 && ~isempty(degree)
                obj.treeDegree = degree;
            end
            obj.clusterTrees = containers.Map('KeyType', 'double', 'ValueType', 'any');
            obj.initialize();
        end

        function initialize(obj)
            % Initialize trees for all clusters in swarm
            clusters = obj.swarm.clusters;
            for i = 1:numel(clusters)
                cID = clusters(i).id;
                obj.rebuildClusterTree(cID);
            end
        end

        function result = join(obj, uavID, clusterID)
            % UAV joins cluster under LKH
            obj.swarm.addUAV(uavID, clusterID);
            cluster = obj.swarm.findCluster(clusterID);
            activeUAVs = cluster.getActiveUAVs();
            nc = numel(activeUAVs);

            obj.rebuildClusterTree(clusterID);

            % In LKH join: leader refreshes keys along path from leaf to root
            % to ensure Backward Secrecy: O(log_d n_c) encryptions
            treeHeight = ceil(log(max(2, nc)) / log(obj.treeDegree));
            encryptionsCount = treeHeight + 1;

            leaderTimer = tic;
            % Generate fresh symmetric keys and encrypt
            for h = 1:encryptionsCount
                freshKey = randi([1, 2^31 - 1]); %#ok<NASGU>
                % Simulated AES-256 encryption latency (~5 us per block)
                for w = 1:20; end
            end
            leaderTime = toc(leaderTimer);

            newGroupKey = randi([1, 2^31 - 1]);
            cluster.groupKey = newGroupKey;

            followerTimer = tic;
            for i = 1:nc
                activeUAVs(i).groupKey = newGroupKey;
                activeUAVs(i).keySynced = true;
            end
            followerTime = toc(followerTimer);

            result = obj.createRekeyResult(activeUAVs, clusterID);
            result.leaderTime = leaderTime;
            result.followerTime = followerTime;
            result.messagesSent = encryptionsCount;
            result.encryptions = encryptionsCount;
            result.decryptions = 1;
            result.keysGenerated = encryptionsCount;

            msgBytes = encryptionsCount * (obj.keySizeBytes + 16);
            obj.addCost(msgBytes);
            obj.recordJoin();
        end

        function result = leave(obj, uavID)
            % Single UAV leaves cluster under LKH
            u = obj.swarm.findUAV(uavID);
            if isempty(u)
                result = [];
                return;
            end

            clusterID = u.clusterID;
            obj.swarm.removeUAV(uavID);
            cluster = obj.swarm.findCluster(clusterID);
            activeUAVs = cluster.getActiveUAVs();
            nc = numel(activeUAVs);

            if isempty(activeUAVs)
                cluster.groupKey = [];
                result = [];
                obj.recordLeave();
                return;
            end

            obj.rebuildClusterTree(clusterID);

            % In LKH single leave: all keys on leaving node's path must be refreshed
            % Forward secrecy requires d encryptions per level: O(d * log_d n_c)
            treeHeight = ceil(log(max(2, nc + 1)) / log(obj.treeDegree));
            encryptionsCount = obj.treeDegree * treeHeight;

            leaderTimer = tic;
            for h = 1:encryptionsCount
                freshKey = randi([1, 2^31 - 1]); %#ok<NASGU>
                for w = 1:20; end
            end
            leaderTime = toc(leaderTimer);

            newGroupKey = randi([1, 2^31 - 1]);
            cluster.groupKey = newGroupKey;

            followerTimer = tic;
            for i = 1:nc
                activeUAVs(i).groupKey = newGroupKey;
                activeUAVs(i).keySynced = true;
            end
            followerTime = toc(followerTimer);

            result = obj.createRekeyResult(activeUAVs, clusterID);
            result.leaderTime = leaderTime;
            result.followerTime = followerTime;
            result.messagesSent = encryptionsCount;
            result.encryptions = encryptionsCount;
            result.decryptions = min(treeHeight, encryptionsCount);
            result.keysGenerated = encryptionsCount;

            msgBytes = encryptionsCount * (obj.keySizeBytes + 16);
            obj.addCost(msgBytes);
            obj.recordLeave();
        end

        function result = batchLeave(obj, uavIDs)
            % Batch leave of B UAVs simultaneously in LKH
            if isempty(uavIDs)
                result = [];
                return;
            end

            firstU = obj.swarm.findUAV(uavIDs(1));
            if isempty(firstU)
                result = [];
                return;
            end
            clusterID = firstU.clusterID;

            for i = 1:numel(uavIDs)
                obj.swarm.removeUAV(uavIDs(i));
            end

            cluster = obj.swarm.findCluster(clusterID);
            activeUAVs = cluster.getActiveUAVs();
            nc = numel(activeUAVs);
            B = numel(uavIDs);

            if isempty(activeUAVs)
                cluster.groupKey = [];
                result = [];
                return;
            end

            obj.rebuildClusterTree(clusterID);

            % In Batch LKH: Affected nodes form a Steiner tree:
            % Communication cost = O(B * log_d(n_c / B)) ciphertexts
            treeHeight = ceil(log(max(2, nc + B)) / log(obj.treeDegree));
            if B >= nc
                encryptionsCount = nc;
            else
                encryptionsCount = min(nc * 2, round(B * (treeHeight - log(max(1, B)) / log(obj.treeDegree) + 1)));
                encryptionsCount = max(obj.treeDegree, encryptionsCount);
            end

            leaderTimer = tic;
            for h = 1:encryptionsCount
                freshKey = randi([1, 2^31 - 1]); %#ok<NASGU>
                for w = 1:20; end
            end
            leaderTime = toc(leaderTimer);

            newGroupKey = randi([1, 2^31 - 1]);
            cluster.groupKey = newGroupKey;

            followerTimer = tic;
            for i = 1:nc
                activeUAVs(i).groupKey = newGroupKey;
                activeUAVs(i).keySynced = true;
            end
            followerTime = toc(followerTimer);

            result = obj.createRekeyResult(activeUAVs, clusterID);
            result.leaderTime = leaderTime;
            result.followerTime = followerTime;
            result.messagesSent = encryptionsCount;
            result.encryptions = encryptionsCount;
            result.decryptions = min(treeHeight, encryptionsCount);
            result.keysGenerated = encryptionsCount;

            msgBytes = encryptionsCount * (obj.keySizeBytes + 16);
            obj.addCost(msgBytes);
            obj.recordLeave();
        end

        function result = failure(obj, uavID)
            result = obj.leave(uavID);
            obj.recordFailure();
        end

        function keysCount = getKeysStoredPerMember(obj, clusterID)
            % Returns number of keys stored in each UAV's local memory
            % In LKH, every member stores path from its leaf to the root:
            % Path length = ceil(log_d(n_c)) + 1 keys
            cluster = obj.swarm.findCluster(clusterID);
            if isempty(cluster)
                keysCount = 1;
                return;
            end
            nc = cluster.count();
            keysCount = ceil(log(max(2, nc)) / log(obj.treeDegree)) + 1;
        end
    end

    methods (Access = private)
        function rebuildClusterTree(obj, clusterID)
            cluster = obj.swarm.findCluster(clusterID);
            if isempty(cluster)
                return;
            end
            activeUAVs = cluster.getActiveUAVs();
            nc = numel(activeUAVs);
            treeHeight = ceil(log(max(2, nc)) / log(obj.treeDegree));

            treeData.nc = nc;
            treeData.height = treeHeight;
            treeData.keysPerMember = treeHeight + 1;
            treeData.totalNodes = round((obj.treeDegree^(treeHeight + 1) - 1) / (obj.treeDegree - 1));
            obj.clusterTrees(clusterID) = treeData;
        end
    end
end
