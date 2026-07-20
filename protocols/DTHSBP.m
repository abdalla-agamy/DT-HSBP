classdef DTHSBP < HSBP
    methods

        function obj = DTHSBP(swarm)

            obj@HSBP(swarm);

        end

        %--------------------------------------------

        function initialize(obj)

            fprintf("DTHSBP initialized\n");

        end

        %--------------------------------------------

        function join(obj, clusterID)

            cfg = obj.cfg;

            % Create candidate UAV
            newID = obj.swarm.nextUAVID;

            candidate = UAV(newID, clusterID, cfg);

            candidate.dt.tick(candidate,cfg);

            % DT evaluation
            if candidate.dt.isStable(cfg)

                % Accept UAV
                obj.swarm.nextUAVID = obj.swarm.nextUAVID + 1;

                obj.swarm.clusters(clusterID).addUAV(candidate);

                % Rekey using inherited HSBP logic
                cluster = obj.swarm.clusters(clusterID);

                cluster.groupKey = ...
                    obj.engine.generateGroupKey(cluster.uavs);

                obj.addCost(cluster.count());

                obj.recordJoin();

            else

                fprintf("Join rejected by DT.\n");

            end

        end

        %--------------------------------------------

        function leave(obj,uavID)
            
             u = obj.swarm.findUAV(uavID);

            if ~u.dt.isStable(obj.cfg)

%             u = obj.swarm.findUAV(uavID);
% 
%             if ~u.dt.isStable(u, obj.cfg)

                fprintf("DT detected unstable UAV %d\n",u.id);

            end

            leave@HSBP(obj,uavID);

        end

        %--------------------------------------------

%         function failure(obj,uavID)
% 
%             FailureEvent.execute(obj.swarm,uavID);
% 
%             obj.metrics.failures = ...
%                 obj.metrics.failures + 1;
% 
%         end

    end

end