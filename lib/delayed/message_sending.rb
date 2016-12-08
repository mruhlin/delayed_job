module Delayed
  module MessageSending
    def send_later(method, *args)
      if args.last.is_a?(Hash)
        priority = args.last.delete(:priority)
        queue = args.last.delete(:queue)
        if args.last.empty?
          args.pop
        end
      end

      priority ||= DJ_DEFAULT_PRIORITY
      queue ||= DJ_DEFAULT_QUEUE

      if defined?($SYNC) && $SYNC
        send(method, *args)
      else
        job = Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, method.to_sym, args), priority, nil, queue)
        SchoolAdmin::Delayed.log_job_queued(job)
        job
      end
    end

    def send_at(time, method, *args)
      job = Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, method.to_sym, args), 0, time, nil)
      SchoolAdmin::Delayed.log_job_queued(job)
      job
    end

    module ClassMethods
      def handle_asynchronously(method, opts={})
        aliased_method, punctuation = method.to_s.sub(/([?!=])$/, ''), $1
        with_method, without_method = "#{aliased_method}_with_send_later#{punctuation}", "#{aliased_method}_without_send_later#{punctuation}"
        define_method(with_method) do |*args|
          args = args.dup
          if opts[:priority] || opts[:queue]
            args.push({
              priority: opts[:priority],
              queue: opts[:queue]
            })
          end
          send_later(without_method, *args)
        end
        alias_method_chain method, :send_later
      end
    end
  end
end
