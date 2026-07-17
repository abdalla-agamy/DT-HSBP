clear
clc

cfg = config();

c = Cluster(1);

u1 = UAV(1,1,cfg);
u2 = UAV(2,1,cfg);
u3 = UAV(3,1,cfg);

c.addUAV(u1);
c.addUAV(u2);
c.addUAV(u3);

fprintf("Cluster size = %d\n", c.count());

disp(c.head.id)

c.removeUAV(1);

fprintf("Cluster size = %d\n", c.count());

disp(c.head.id)