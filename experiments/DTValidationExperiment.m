function result = DTValidationExperiment()
%DTVALIDATIONEXPERIMENT Paper-aligned Digital Twin validation scenario.
%
% This is a validation experiment, not a swarm-scale performance study.
% It follows the paper's qualitative DT validation scenario:
%   - stable operation before t = 40 s;
%   - controlled instability introduced at t = 40 s;
%   - DT residual rises after the disturbance;
%   - the leave threshold is crossed;
%   - a scheduled rekey is evaluated at t = 55 s.
%
% The paper does not specify a unique numerical disturbance model. The
% implementation therefore makes the disturbance parameters explicit
% below rather than silently presenting them as paper measurements.

    fprintf('============================================\n');
    fprintf('DT Validation Experiment\n');
    fprintf('============================================\n');

    cfg = config();

    % Validation-scenario parameters.
    cfg.numUAVs = 200;
    cfg.numClusters = 1;
    cfg.clusterSize = cfg.numUAVs;
    cfg.joinRate = 0;
    cfg.leaveRate = 0;
    cfg.failureRate = 0;
    cfg.timeStep = 1;
    cfg.simulationTime = 55;

    disturbanceTime = 40;
    rekeyTime = 55;
    disturbedUAVID = 2;
    positionPerturbation = [10 0];

    rng(cfg.randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);
    sim = Simulation(cfg, protocol);

    disturbedUAV = swarm.findUAV(disturbedUAVID);
    if isempty(disturbedUAV)
        error('DTValidationExperiment:MissingUAV', ...
            'Disturbed UAV %d was not found.', disturbedUAVID);
    end

    samples = zeros(cfg.simulationTime + 1, 2);
    samples(1,:) = [0 disturbedUAV.dt.stabilityScore];

    thresholdCrossed = false;
    thresholdTime = NaN;
    rekeyPerformed = false;
    rekeyResult = [];

    for t = 1:cfg.simulationTime

        % The paper describes instability beginning at t=40 s and
        % continuing until the scheduled rekey. Because the current DT
        % predictor is reset from the latest actual state after each
        % residual calculation, a one-time displacement would disappear
        % after one DT cycle. Therefore the diagnostic applies the
        % controlled disturbance throughout the validation interval.
        if t >= disturbanceTime && t <= rekeyTime
            disturbedUAV.position = ...
                disturbedUAV.position + positionPerturbation;
        end

        % The normal Simulation lifecycle performs physical evolution,
        % then the Digital Twin update.
        sim.step();

        score = disturbedUAV.dt.stabilityScore;
        samples(t + 1,:) = [sim.currentTime score];

        if ~thresholdCrossed && score > cfg.thetaLeave
            thresholdCrossed = true;
            thresholdTime = sim.currentTime;
        end

        % The paper's validation scenario schedules the rekey at t=55 s.
        % We invoke the protocol leave operation directly here so that the
        % returned RekeyResult exposes the DT-HSBP predicted-leave set.
        if t == rekeyTime
            requestUAV = swarm.findUAV(3);

            if isempty(requestUAV)
                error('DTValidationExperiment:MissingRequester', ...
                    'Requesting UAV 3 was not found.');
            end

            beforeRekeyCount = swarm.totalUAVs();
            rekeyResult = protocol.leave(requestUAV.id);
            rekeyPerformed = ~isempty(rekeyResult);

            if rekeyPerformed
                predictedLeaves = rekeyResult.predictedLeaves;

                % Mirror the Simulation.processLeaveRequest() bookkeeping
                % without modifying production simulation code.
                sim.dtManager.removeUAV(requestUAV.id);

                for i = 1:numel(predictedLeaves)
                    sim.dtManager.removeUAV(predictedLeaves(i));
                end

                afterRekeyCount = swarm.totalUAVs();

                if afterRekeyCount >= beforeRekeyCount
                    error('DTValidationExperiment:InvalidRemoval', ...
                        'The scheduled rekey did not reduce membership.');
                end
            end
        end
    end

    fprintf('UAVs                 : %d\n', cfg.numUAVs);
    fprintf('Disturbance time      : %.1f s\n', disturbanceTime);
    fprintf('Rekey time            : %.1f s\n', rekeyTime);
    fprintf('Position perturbation : [%g %g]\n', positionPerturbation);
    fprintf('Leave threshold       : %.6f\n', cfg.thetaLeave);
    fprintf('Threshold crossed     : %d\n', thresholdCrossed);
    fprintf('Threshold time        : %.1f s\n', thresholdTime);
    fprintf('Rekey performed       : %d\n', rekeyPerformed);

    if rekeyPerformed
        fprintf('Predicted leaves      : %s\n', ...
            mat2str(rekeyResult.predictedLeaves));
        fprintf('Messages sent         : %d\n', ...
            rekeyResult.messagesSent);
    else
        fprintf('Predicted leaves      : []\n');
        fprintf('Messages sent         : 0\n');
    end

    % Validation assertions.
    assert(thresholdCrossed, ...
        'DTValidationExperiment:ThresholdNotCrossed', ...
        'The controlled disturbance did not cross thetaLeave.');

    assert(rekeyPerformed, ...
        'DTValidationExperiment:RekeyNotPerformed', ...
        'The scheduled leave/rekey did not succeed.');

    assert(~isempty(rekeyResult.predictedLeaves), ...
        'DTValidationExperiment:NoPredictedLeaves', ...
        'No DT predicted leaves were generated at the scheduled rekey.');

    result = struct();
    result.time = samples(:,1);
    result.stabilityScore = samples(:,2);
    result.disturbanceTime = disturbanceTime;
    result.rekeyTime = rekeyTime;
    result.threshold = cfg.thetaLeave;
    result.thresholdCrossed = thresholdCrossed;
    result.thresholdTime = thresholdTime;
    result.rekeyPerformed = rekeyPerformed;
    result.rekeyResult = rekeyResult;

    fprintf('\nDT validation experiment: PASS\n');
    fprintf('============================================\n');

end
