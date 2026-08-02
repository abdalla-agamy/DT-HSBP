clear; clc;
clear classes;

cfg = config();

swarm = Swarm(cfg);

uav = swarm.addUAV(1,1);

agent = DTAgent(uav, cfg);

agent.observe(uav);

for k = 1:20

    % Move UAV however your model updates it
    % e.g. uav.position = uav.position + randn(1,3);

    agent.update%()  (uav,cfg);

    score = agent.stabilityScore;

    fprintf("Step %2d : Score = %.4f\n",k,score);

    assert(score > 0.0 && score <= 1, ...
        'Invalid stability score.');

    stable = agent.isStable(cfg);

    assert(islogical(stable), ...
        'isStable() must return logical.');

end

fprintf("\nPASS\n");

% clear; clc;
% clear classes;
% rehash;
% 
% %% Configuration
% cfg = config();
% 
% %% Build protocol
% protocol = HSBP(cfg);
% 
% %% Build simulation
% sim = Simulation(cfg, protocol);
% 
% fprintf("Running simulation...\n");
% 
% while sim.currentTime < cfg.simulationTime
% 
%     sim.step();
% 
%     active = sim.swarm.getActiveUAVs();
% 
%     for k = 1:numel(active)
% 
%         agent = sim.dtManager.findAgent(active(k).id);
% 
%         if isempty(agent)
%             continue;
%         end
% 
%         %% Check stability score
%         score = agent.stabilityScore;
% 
%         if ~(score > 0 && score <= 1)
% 
%             error(['Invalid stability score for UAV %d : %f'], ...
%                 active(k).id, score);
% 
%         end
% 
%         %% Check isStable()
%         stable = agent.isStable(cfg);
% 
%         if ~islogical(stable)
% 
%             error(['isStable() did not return logical for UAV %d'], ...
%                 active(k).id);
% 
%         end
% 
%     end
% 
% end
% 
% fprintf("\n=================================\n");
% fprintf("Digital Twin Stability Check PASSED\n");
% fprintf("=================================\n");
% 
% 
% % clear all; clc;
% % clear classes
% % rehash
% % 
% % %% Load configuration
% % cfg = config();
% % 
% % %% Build swarm
% % swarm = Swarm(cfg);
% % 
% % %% 1. Poisson Event Generator
% % gen = PoissonEventGenerator(cfg);
% % % eventCounts = gen.generate();
% % eventCounts.join = 2;
% % eventCounts.leave = 1;
% % eventCounts.failure = 0;
% % 
% % disp('===== PoissonEventGenerator =====');
% % disp(eventCounts);
% % 
% % %% 2. Event Factory
% % factory = EventFactory(swarm);
% % events = factory.createEvents(eventCounts,0);
% % 
% % fprintf('\n===== EventFactory =====\n');
% % fprintf('%d events created.\n',numel(events));
% % 
% % %% 3. Event Queue
% % queue = EventQueue();
% % 
% % for k = 1:numel(events)
% %     queue.schedule(events{k});
% % end
% % 
% % fprintf('\n===== EventQueue =====\n');
% % fprintf('Queue size = %d\n',queue.count());
% % 
% % %% 4. Pop events
% % dueEvents = queue.popDueEvents(0);
% % % class(dueEvents)
% % % class(dueEvents{1})
% % % celldisp(dueEvents)
% % 
% % fprintf('\n===== Processing Events =====\n');
% % 
% % dtManager = DigitalTwinManager(cfg);
% % 
% % for k = 1:numel(dueEvents)
% % 
% %     e = dueEvents{k};
% % 
% %     fprintf('\nEvent %d : %s\n',k,class(e));
% % 
% %     if isa(e,'JoinEvent')
% % 
% %         fprintf('processJoinRequest()\n');
% % 
% %         uav = swarm.addUAV(e.uavID,e.clusterID);
% % 
% %         fprintf('Swarm.addUAV() OK\n');
% % 
% %         try
% %             dtManager.registerUAV(uav);
% %             fprintf('DigitalTwinManager.registerUAV() OK\n');
% %         catch ME
% %             fprintf('registerUAV FAILED:\n%s\n',ME.message);
% %         end
% % 
% %     end
% % end
% % 
% % %% 5. Update Digital Twins
% % fprintf('\n===== Digital Twin Update =====\n');
% % 
% % try
% %     dtManager.update();
% %     fprintf('DTAgent.update() OK\n');
% % catch ME
% %     fprintf('DT update FAILED:\n%s\n',ME.message);
% % end