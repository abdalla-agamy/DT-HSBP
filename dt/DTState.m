classdef DTState

    properties

        id
        clusterID
        
        position
        velocity
        energy
        linkQuality
        keySynced

    end

    methods

        function obj = DTState(uav)

            obj.id = uav.id;
            obj.clusterID = uav.clusterID;

            obj.position = uav.position;
            obj.velocity = uav.velocity;
            obj.energy = uav.energy;
            obj.linkQuality = uav.linkQuality;
            obj.keySynced = uav.keySynced;

        end

    end

end