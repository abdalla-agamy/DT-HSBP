classdef TGDH < Protocol
    %TGDH Tree-based Group Diffie-Hellman Group Key Management Protocol
    % Implements canonical contributory tree-based Diffie-Hellman key agreement
    % (Kim, Perrig, & Tsudik, ACM TISSEC / IEEE ToN 2004).
    % Each cluster maintains a balanced binary Diffie-Hellman tree.
    % Every node v maintains a private key K_v and a blinded public key BK_v = g^(K_v) mod p.
    % Member storage overhead = O(log_2 n_c) secret keys + O(log_2 n_c) blinded keys.
    % Leave communication overhead = O(log_2 n_c) broadcast blinded keys.
    % Leave computation overhead = O(log_2 n_c) modular exponentiations per member.

    properties
        treeDegree = 2;          % Canonically binary tree (d = 2)
        tokenSizeBytes = 128;    % 1024-bit Diffie-Hellman public token (128 bytes)
        dhPrime = 2147483647;    % Mersenne prime 2^31 - 1
        dhGenerator = 7;         % Primitive root generator
        clusterTrees             % Map of clusterID -> Tree structure
    end

    methods
        function obj = TGDH(swarm, degree)
            obj@Protocol(swarm);
            if nargin >= 2 && ~isempty(degree)
                obj.treeDegree = degree;
            end
            obj.clusterTrees = containers.Map('KeyType', 'double', 'ValueType', 'any');
            obj.initialize();
        end

        function initialize(obj)
            % Initialize DH trees for all clusters in swarm
            clusters = obj.swarm.clusters;
            for i = 1:numel(clusters)
                cID = clusters(i).id;
                obj.rebuildClusterTree(cID);
            end
        end

        function result = join(obj, uavID, clusterID)
            % UAV joins cluster under TGDH
            obj.swarm.addUAV(uavID, clusterID);
            cluster = obj.swarm.findCluster(clusterID);
            activeUAVs = cluster.getActiveUAVs();
            nc = numel(activeUAVs);

            obj.rebuildClusterTree(clusterID);

            % In TGDH join: sponsor UAV generates a fresh key and computes
            % blinded keys along its path to root: 2 * log_2(n_c) modexps
            treeHeight = ceil(log2(max(2, nc)));
            modexpCount = 2 * treeHeight;

            leaderTimer = tic;
            % Simulate modular exponentiations for updated path
            for h = 1:modexpCount
                dummyExp = randi([1000, 50000]);
                obj.modExp(obj.dhGenerator, dummyExp, obj.dhPrime);
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
            result.messagesSent = treeHeight; % Sponsor broadcasts new blinded keys
            result.encryptions = 0;           % TGDH uses asymmetric DH, not symmetric cipher
            result.decryptions = 0;
            result.keysGenerated = treeHeight;

            msgBytes = treeHeight * obj.tokenSizeBytes;
            obj.addCost(msgBytes);
            obj.recordJoin();
        end

        function result = leave(obj, uavID)
            % Single UAV leaves cluster under TGDH
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

            % In TGDH single leave: sponsor node (sibling of departed node)
            % updates its key and computes new keys and blinded keys up to root.
            % Sponsor modexps: 2 * treeHeight (1 for secret key, 1 for blinded key)
            treeHeight = ceil(log2(max(2, nc + 1)));
            modexpCount = 2 * treeHeight;

            leaderTimer = tic;
            for h = 1:modexpCount
                dummyExp = randi([1000, 50000]);
                obj.modExp(obj.dhGenerator, dummyExp, obj.dhPrime);
            end
            leaderTime = toc(leaderTimer);

            newGroupKey = randi([1, 2^31 - 1]);
            cluster.groupKey = newGroupKey;

            followerTimer = tic;
            % Each surviving follower computes 1 modexp per ancestor level
            for i = 1:nc
                activeUAVs(i).groupKey = newGroupKey;
                activeUAVs(i).keySynced = true;
            end
            followerTime = toc(followerTimer);

            result = obj.createRekeyResult(activeUAVs, clusterID);
            result.leaderTime = leaderTime;
            result.followerTime = followerTime;
            result.messagesSent = treeHeight; % Blinded keys broadcasted by sponsor
            result.encryptions = 0;
            result.decryptions = 0;
            result.keysGenerated = treeHeight;

            msgBytes = treeHeight * obj.tokenSizeBytes;
            obj.addCost(msgBytes);
            obj.recordLeave();
        end

        function result = batchLeave(obj, uavIDs)
            % Batch leave of B members under TGDH
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

            if isempty(activeUAVs)
                cluster.groupKey = [];
                result = [];
                obj.recordLeave();
                return;
            end

            obj.rebuildClusterTree(clusterID);

            % In batch TGDH leave: updated subtree requires computing blinded keys
            % across the modified Steiner subtrees: O(B * log_2(n_c / B))
            treeHeight = ceil(log2(max(2, nc + numel(uavIDs))));
            B = numel(uavIDs);
            effectiveLevels = min(treeHeight, ceil(log2(max(2, (nc + B) / B))));
            tokensSent = min(nc, B * effectiveLevels);
            modexpsCount = 2 * tokensSent;

            leaderTimer = tic;
            for h = 1:modexpsCount
                dummyExp = randi([1000, 50000]);
                obj.modExp(obj.dhGenerator, dummyExp, obj.dhPrime);
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
            result.messagesSent = tokensSent;
            result.encryptions = 0;
            result.decryptions = 0;
            result.keysGenerated = tokensSent;

            msgBytes = tokensSent * obj.tokenSizeBytes;
            obj.addCost(msgBytes);
            obj.recordLeave();
        end

        function result = failure(obj, uavID)
            % UAV failure triggers a leave event
            result = obj.leave(uavID);
            obj.recordFailure();
        end

        function keysCount = getKeysStoredPerMember(obj, uavID)
            % Returns number of cryptographic keys stored by member in TGDH:
            % Path of secret keys to root (h + 1) + Sibling blinded public keys (h)
            % Total stored = 2 * h + 1 keys = O(log_2 n_c)
            u = obj.swarm.findUAV(uavID);
            if isempty(u)
                keysCount = 0;
                return;
            end
            cluster = obj.swarm.findCluster(u.clusterID);
            nc = numel(cluster.getActiveUAVs());
            treeHeight = ceil(log2(max(2, nc)));
            keysCount = 2 * treeHeight + 1; % Secret keys + blinded keys along path
        end
    end

    methods (Access = private)
        function rebuildClusterTree(obj, clusterID)
            % Maintains logical tree topology indexing active members
            cluster = obj.swarm.findCluster(clusterID);
            if isempty(cluster)
                return;
            end
            activeUAVs = cluster.getActiveUAVs();
            nc = numel(activeUAVs);
            if nc == 0
                obj.clusterTrees(clusterID) = struct('height', 0, 'numNodes', 0);
                return;
            end
            treeHeight = ceil(log2(max(2, nc)));
            totalNodes = 2^(treeHeight + 1) - 1;
            obj.clusterTrees(clusterID) = struct('height', treeHeight, 'numNodes', totalNodes);
        end

        function val = modExp(~, base, exponent, modulus)
            % Fast modular exponentiation (base^exponent mod modulus)
            val = 1;
            b = mod(base, modulus);
            e = exponent;
            while e > 0
                if mod(e, 2) == 1
                    val = mod(val * b, modulus);
                end
                b = mod(b * b, modulus);
                e = floor(e / 2);
            end
        end
    end
end
