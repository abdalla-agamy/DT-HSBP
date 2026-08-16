classdef ExperimentResult < handle
    %EXPERIMENTRESULT Results collected from one experiment run.
    %
    % This class stores protocol-independent experiment observations.
    % Statistical aggregation is intentionally kept outside this class.

    properties

        % Experiment identity
        protocol = ""
        eventType = ""
        runID = 0
        randomSeed = []

        % Operation outcome
        success = false
        status = "NotExecuted"

        % Network configuration
        swarmSize = 0
        clusterCount = 0
        clusterSize = 0

        % Workload
        eventCount = 0

        % Performance measurements
        leaderTime = 0
        followerTime = 0
        dtAdmissionTime = 0
        messageCount = 0
        messageBytes = 0

        % Protocol / DT outcomes
        rekeyCount = 0
        predictedLeaves = 0
        acceptedJoins = 0
        rejectedJoins = 0

        % DT validation time-series (optional)
        time = []
        stabilityScore = []
        leaveThreshold = []
        rekeyTime = []

    end

    methods

        function obj = ExperimentResult(varargin)
            %EXPERIMENTRESULT Construct an empty result or initialize fields.
            %
            % Optional name/value pairs are accepted for convenient setup.

            if mod(nargin,2) ~= 0
                error('ExperimentResult:InvalidArguments', ...
                    'Arguments must be supplied as name/value pairs.');
            end

            for i = 1:2:nargin
                name = varargin{i};
                value = varargin{i+1};

                if ~(ischar(name) || isstring(name))
                    error('ExperimentResult:InvalidProperty', ...
                        'Property names must be character vectors or strings.');
                end

                name = char(name);

                if ~isprop(obj,name)
                    error('ExperimentResult:UnknownProperty', ...
                        'Unknown ExperimentResult property: %s', name);
                end

                obj.(name) = value;
            end
        end

        function result = toStruct(obj)
            %TOSTRUCT Return the collected result as a MATLAB struct.

            propertiesList = properties(obj);
            result = struct();

            for i = 1:numel(propertiesList)
                name = propertiesList{i};
                result.(name) = obj.(name);
            end
        end

        function reset(obj)
            %RESET Restore all result fields to their initial values.

            defaults = ExperimentResult();
            propertiesList = properties(obj);

            for i = 1:numel(propertiesList)
                name = propertiesList{i};
                obj.(name) = defaults.(name);
            end
        end

    end
end
