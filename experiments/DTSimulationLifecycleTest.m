function DTSimulationLifecycleTest()
%DTSIMULATIONLIFECYCLETEST Validate the normal Simulation/DT lifecycle.
%
% This is an integration diagnostic, not a performance experiment.
% It disables stochastic events and advances the normal Simulation.step()
% lifecycle. The current physical model and predictor are intentionally
% matched, so the DT residual is expected to remain approximately zero.
%
% The test therefore documents whether naturally evolving simulation state
% can trigger DT-HSBP predicted leaves without artificial perturbation.

    fprintf('============================================\n');
    fprintf('DT Simulation Lifecycle Test\n');
    fprintf('============================================\n');

    cfg = config();

    % Disable stochastic events so this test isolates the DT lifecycle.
    cfg.joinRate = 0;
    cfg.leaveRate = 0;
    cfg.failureRate = 0;
    cfg.simulationTime = 3;

    rng(cfg.randomSeed);

    swarm = Swarm(cfg);
    protocol = DTHSBP(swarm);
    sim = Simulation(cfg, protocol);

    initialCount = sim.swarm.totalUAVs();

    fprintf('Initial UAVs         : %d\n', initialCount);
    fprintf('Simulation steps     : %d\n', cfg.simulationTime / cfg.timeStep);
    fprintf('DT interval          : %.3f s\n', cfg.dtInterval);
    fprintf('Prediction horizon   : %.3f s\n', cfg.predictionHorizon);

    for step = 1:(cfg.simulationTime / cfg.timeStep)
        sim.step();

        activeUAVs = sim.swarm.getActiveUAVs();
        scores = zeros(1, numel(activeUAVs));

        for i = 1:numel(activeUAVs)
            scores(i) = activeUAVs(i).dt.stabilityScore;
        end

        if isempty(scores)
            maxScore = NaN;
            minScore = NaN;
        else
            maxScore = max(scores);
            minScore = min(scores);
        end

        fprintf(['Step %d | time=%.1f | active=%d | ', ...
            'min stability=%.12g | max stability=%.12g\n'], ...
            step, sim.currentTime, sim.swarm.activeUAVs(), ...
            minScore, maxScore);
    end

    activeUAVs = sim.swarm.getActiveUAVs();
    scores = zeros(1, numel(activeUAVs));

    for i = 1:numel(activeUAVs)
        scores(i) = activeUAVs(i).dt.stabilityScore;
    end

    assert(sim.swarm.totalUAVs() == initialCount, ...
        'DTSimulationLifecycleTest:UnexpectedMembershipChange', ...
        'Membership changed although all stochastic event rates are zero.');

    assert(all(isfinite(scores)), ...
        'DTSimulationLifecycleTest:InvalidStabilityScore', ...
        'A DT stability score is non-finite.');

    tolerance = 1e-12;

    if isempty(scores)
        maxScore = 0;
    else
        maxScore = max(scores);
    end

    assert(maxScore <= tolerance, ...
        'DTSimulationLifecycleTest:UnexpectedResidual', ...
        ['The current matched physical/predictive model produced a ', ...
         'non-zero residual unexpectedly.']);

    predictedCandidates = activeUAVs( ...
        arrayfun(@(u) u.dt.stabilityScore > cfg.thetaLeave, activeUAVs));

    fprintf('\nFinal maximum stability : %.12g\n', maxScore);
    fprintf('Leave threshold          : %.12g\n', cfg.thetaLeave);
    fprintf('Predicted-leave eligible: %d\n', numel(predictedCandidates));

    assert(isempty(predictedCandidates), ...
        'DTSimulationLifecycleTest:UnexpectedPredictedLeaves', ...
        'Natural simulation state unexpectedly crossed thetaLeave.');

    fprintf('\nDT simulation lifecycle validation: PASS\n');
    fprintf(['Result: the current normal simulation lifecycle does not ', ...
        'naturally generate DT predicted leaves under the matched ', ...
        'physical/predictive model.\n']);
    fprintf('============================================\n');

end
