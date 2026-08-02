classdef EventQueue < handle

    properties (Access = private)

        %eventList Event = Event.empty(1,0);
        eventList={};
        %eventList Event;
%         eventList = Event.empty;

    end

    methods

        function obj = EventQueue()

            %obj.eventList = Event.empty;%(1,0);%.empty;%(0,1);
            obj.eventList = {};
%             obj.eventList = Event.empty;
        end

        function schedule(obj, event)

%             obj.eventList(end+1) = event;
% 
%             [~, idx] = sort([obj.eventList.time]);
% 
%             obj.eventList = obj.eventList(idx);

            obj.eventList{end+1} = event;
        
            [~,idx] = sort(cellfun(@(e)e.time,obj.eventList));
        
            obj.eventList = obj.eventList(idx);


        end

        function dueEvents = popDueEvents(obj, currentTime)

%             mask = [obj.eventList.time] <= currentTime;
% 
%             dueEvents = obj.eventList(mask);
% 
%             obj.eventList(mask) = [];
            
            if isempty(obj.eventList)
                dueEvents = {};
                return;
            end
            
            mask = cellfun(@(e)e.time,obj.eventList) <= currentTime;
            
            dueEvents = obj.eventList(mask);
            
            obj.eventList(mask) = [];

        end

        function tf = isEmpty(obj)

            tf = isempty(obj.eventList);

        end

        function n = count(obj)

            n = numel(obj.eventList);

        end

    end

end