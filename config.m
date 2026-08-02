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

%% ===============================
%  Mobility
% ================================
cfg.maxVelocity  = 20;        % m/s
cfg.areaX        = 1000;
cfg.areaY        = 1000;

%% ===============================
%  Communication
% ================================
cfg.packetSize   = 256;       % Bytes
cfg.mtu          = 1500;      % Bytes

%% ===============================
%  Simulation
% ================================
cfg.timeStep     = 1;         % Second
cfg.simulationTime = 100;     % Seconds

%% ===============================
% Stochastic Event Model
% ================================
cfg.joinRate = 0.05;    % λJ (joins/second)
cfg.leaveRate = 0.03;    % λL (leaves/second)
cfg.failureRate = 0.01;    % λF (failures/second)

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