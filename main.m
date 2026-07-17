clear
clc

cfg = config();

swarm = Swarm(cfg);

fprintf("Initial UAVs : %d\n", swarm.totalUAVs());

JoinEvent.execute(swarm,3);

fprintf("After Join : %d\n", swarm.totalUAVs());

FailureEvent.execute(swarm,500);

fprintf("Active UAVs : %d\n", swarm.activeUAVs());

LeaveEvent.execute(swarm,100);

fprintf("After Leave : %d\n", swarm.totalUAVs());