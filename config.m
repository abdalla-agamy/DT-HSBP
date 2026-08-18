function cfg = config()

%% ===============================
%  Swarm Configuration
% ================================
cfg.numUAVs      = 1000;      % Total UAVs
cfg.numClusters  = 5;         % Number of clusters
cfg.clusterSize  = cfg.numUAVs / cfg.numClusters;

%% ===============================
%  Cryptography
% ================================
cfg.prime        = 2147483647;    % Large prime (simulation)
cfg.generator    = 5;

%% ===============================
%  Digital Twin
% ================================
cfg.dtInterval   = 1.0;       % DT update period (s)
cfg.predictionHorizon = 1.0;  % Prediction window
cfg.energyConsumptionRate = 0.1;

cfg.thetaJoin    = 1.0;
cfg.thetaLeave   = 2.5;
cfg.thetaCluster = 3.0;

cfg.stabilityThreshold = 0.60;

%% ===============================
%  Mobility
% ================================
cfg.maxVelocity  = 20;        % m/s
cfg.areaX        = 1000;
cfg.areaY        = 1000;

%% ============================================================
% Communication Cost Model
% ============================================================

cfg.keySize = 32;          % bytes (256-bit symmetric key)
cfg.headerSize = 16;       % bytes
cfg.controlSize = 8;       % bytes
cfg.messageSize = ...
    cfg.headerSize + ...
    cfg.controlSize + ...
    cfg.keySize;
cfg.packetSize   = 256;       % Bytes
cfg.mtu          = 1500;      % Bytes

%% ===============================
%  Simulation
% ================================
cfg.timeStep     = 1;         % Second
cfg.simulationTime = 10;     % Seconds

%% ===============================
% Stochastic Event Model
% ================================
cfg.joinRate = 0.5;    % λJ (joins/second)
cfg.leaveRate = 0.3;    % λL (leaves/second)
cfg.failureRate = 0.1;    % λF (failures/second)

%% ===============================
% DT Disturbance Model
% ================================
% Independent physical disturbance process. Disabled by default so the
% normal Poisson Join/Leave/Failure baseline remains unchanged.
% When enabled, each simulation step samples
% N_D ~ Poisson(dtDisturbanceRate * timeStep).
cfg.dtDisturbanceEnabled = true;
cfg.dtDisturbanceRate = 0.05;       % disturbances/second
cfg.dtDisturbanceUAVCount = 2;      % affected UAVs per disturbance
cfg.dtDisturbancePositionStep = [10 0];
cfg.dtDisturbanceVelocityStep = [0 0];
cfg.dtDisturbanceEnergyDrop = 0;

cfg.dtPredictedDepartureEnabled = true;

% DT stochastic departure realization model:
%   λ_DT(S) = λ_L * exp(S/thetaLeave - 1)
%   P_realize = 1 - exp(-λ_DT(S) * predictionHorizon)
%
% The model anchors the DT realization hazard to the configured ordinary
% leave hazard at the leave threshold. Instability above/below the threshold
% increases/decreases the conditional realization hazard exponentially.
% No independent probability constant is introduced.
cfg.dtDepartureHazardModel = "threshold_anchored_exponential";

%% ===============================
% Residual Weights
% ===============================

cfg.residualWeights.position = 1.0;
cfg.residualWeights.velocity = 1.0;
cfg.residualWeights.energy = 1.0;
cfg.residualWeights.linkQuality = 1.0;
cfg.residualWeights.keySynced = 1.0;


cfg.randomSeed   = 42;

rng(cfg.randomSeed);

end
