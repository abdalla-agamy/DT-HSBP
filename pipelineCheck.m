clear; clc;
clear classes
rehash

%% Load configuration
cfg = config();

%% Build swarm
swarm = Swarm(cfg);

%% 1. Poisson Event Generator
gen = PoissonEventGenerator(cfg);
eventCounts = gen.generate();

disp('===== PoissonEventGenerator =====');
disp(eventCounts);

%% 2. Event Factory
factory = EventFactory(swarm);
events = factory.createEvents(eventCounts,0);

fprintf('\n===== EventFactory =====\n');
fprintf('%d events created.\n',numel(events));

%% 3. Event Queue
queue = EventQueue();

for k = 1:numel(events)
    queue.schedule(events(k));
end

fprintf('\n===== EventQueue =====\n');
fprintf('Queue size = %d\n',queue.count());

%% 4. Pop events
dueEvents = queue.popDueEvents(0);

fprintf('\n===== Processing Events =====\n');

dtManager = DigitalTwinManager(cfg);

for k = 1:numel(dueEvents)

    e = dueEvents(k);

    fprintf('\nEvent %d : %s\n',k,class(e));

    if isa(e,'JoinEvent')

        fprintf('processJoinRequest()\n');

        uav = swarm.addUAV(e.uavID,e.clusterID);

        fprintf('Swarm.addUAV() OK\n');

        try
            dtManager.registerUAV(uav);
            fprintf('DigitalTwinManager.registerUAV() OK\n');
        catch ME
            fprintf('registerUAV FAILED:\n%s\n',ME.message);
        end

    end
end

%% 5. Update Digital Twins
fprintf('\n===== Digital Twin Update =====\n');

try
    dtManager.update();
    fprintf('DTAgent.update() OK\n');
catch ME
    fprintf('DT update FAILED:\n%s\n',ME.message);
end