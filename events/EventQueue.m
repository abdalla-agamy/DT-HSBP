classdef EventQueue < handle

    properties (Access = private)

        eventList Event = Event.empty;

    end

    methods

        function obj = EventQueue()

            obj.eventList = Event.empty;
        end

        function schedule(obj, event)

            obj.eventList(end+1) = event;

            [~, idx] = sort([obj.eventList.time]);

            obj.eventList = obj.eventList(idx);

        end

        function dueEvents = popDueEvents(obj, currentTime)

            dueEvents = obj.eventQueue.popDueEvents(obj.currentTime);

            for i = 1:numel(dueEvents)
                dueEvents(i).execute(obj);
            end

        end

        function tf = isEmpty(obj)

            tf = isempty(obj.eventList);

        end

        function n = count(obj)

            n = numel(obj.eventList);

        end

    end

end