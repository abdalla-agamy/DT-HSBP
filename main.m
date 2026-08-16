clear
clc

cfg = config();

swarm = Swarm(cfg);

protocol = DTHSBP(swarm);

sim = Simulation(cfg,protocol);

fprintf("Initial UAVs : %d\n",sim.swarm.totalUAVs());

sim.step();

fprintf("Current time : %.1f\n",sim.currentTime);
fprintf("Active UAVs  : %d\n",sim.swarm.activeUAVs());

sim.printStatistics();