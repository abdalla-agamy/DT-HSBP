function report = DTEngineResidualDiagnostic(swarmSize, randomSeed)
%DTEngineRESIDUALDIAGNOSTIC Inspect DT residual components before/after disturbance.
%
% Diagnostic only. No protocol, threshold, predictor, or physical-model changes.

    if nargin < 1
        swarmSize = 1000;
    end
    if nargin < 2
        randomSeed = 42;
    end

    cfg = config();
    cfg.numUAVs = swarmSize;
    if mod(cfg.numUAVs, cfg.numClusters) ~= 0
        error('DTEngineResidualDiagnostic:Configuration', ...
            'swarmSize must be divisible by numClusters.');
    end
    cfg.clusterSize = cfg.numUAVs / cfg.numClusters;
    cfg.randomSeed = randomSeed;
    rng(randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);
    sim = Simulation(cfg, protocol);

    % Establish prediction state at t=0.
    sim.updateDigitalTwins();

    disturbanceTime = 40.0;
    perturbation = [10 0];
    targetCluster = 1;

    while sim.currentTime < disturbanceTime
        sim.step();
    end

    members = swarm.findCluster(targetCluster).getActiveUAVs();
    if numel(members) < 3
        error('DTEngineResidualDiagnostic:Population', ...
            'Target cluster must contain at least three active UAVs.');
    end

    disturbedIDs = [members(2).id, members(3).id];
    controlID = members(1).id;

    beforeDisturbed = captureComponents(swarm.findUAV(disturbedIDs(1)), cfg);
    beforeControl = captureComponents(swarm.findUAV(controlID), cfg);

    for i = 1:numel(disturbedIDs)
        uav = swarm.findUAV(disturbedIDs(i));
        if ~isempty(uav)
            uav.position = uav.position + perturbation;
        end
    end

    sim.updateDigitalTwins();

    afterDisturbed = captureComponents(swarm.findUAV(disturbedIDs(1)), cfg);
    afterControl = captureComponents(swarm.findUAV(controlID), cfg);

    report = struct();
    report.protocol = "DTHSBP";
    report.swarmSize = swarmSize;
    report.randomSeed = randomSeed;
    report.targetCluster = targetCluster;
    report.disturbedIDs = disturbedIDs;
    report.controlID = controlID;
    report.perturbation = perturbation;
    report.disturbanceTime = disturbanceTime;
    report.beforeDisturbed = beforeDisturbed;
    report.afterDisturbed = afterDisturbed;
    report.beforeControl = beforeControl;
    report.afterControl = afterControl;

    printOne('DISTURBED UAV', disturbedIDs(1), beforeDisturbed, afterDisturbed);
    printOne('CONTROL UAV', controlID, beforeControl, afterControl);
end

function c = captureComponents(uav, cfg)
    if isempty(uav)
        error('DTEngineResidualDiagnostic:MissingUAV', 'UAV not found.');
    end

    actual = DTState(uav);
    predicted = uav.dt.predictedState;
    if isempty(predicted)
        error('DTEngineResidualDiagnostic:NoPrediction', ...
            'DT predicted state is empty for UAV %d.', uav.id);
    end

    c.dp = norm(actual.position - predicted.position);
    c.dv = norm(actual.velocity - predicted.velocity);
    c.de = abs(actual.energy - predicted.energy);
    c.dl = abs(actual.linkQuality - predicted.linkQuality);
    c.dk = double(actual.keySynced ~= predicted.keySynced);
    c.residual = Residual.compute(actual, predicted, cfg);
    c.actualPosition = actual.position;
    c.predictedPosition = predicted.position;
    c.actualVelocity = actual.velocity;
    c.predictedVelocity = predicted.velocity;
end

function printOne(label, id, before, after)
    fprintf('\n--- %s (ID %d) ---\n', label, id);
    fprintf('Component          Before         After\n');
    fprintf('Position residual  %.9f      %.9f\n', before.dp, after.dp);
    fprintf('Velocity residual  %.9f      %.9f\n', before.dv, after.dv);
    fprintf('Energy residual    %.9f      %.9f\n', before.de, after.de);
    fprintf('Link residual      %.9f      %.9f\n', before.dl, after.dl);
    fprintf('Key residual       %.9f      %.9f\n', before.dk, after.dk);
    fprintf('Total residual     %.9f      %.9f\n', before.residual, after.residual);
    fprintf('Actual position before/after     : [%g %g] / [%g %g]\n', ...
        before.actualPosition, after.actualPosition);
    fprintf('Predicted position before/after  : [%g %g] / [%g %g]\n', ...
        before.predictedPosition, after.predictedPosition);
end
