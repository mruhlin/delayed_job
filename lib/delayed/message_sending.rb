module Delayed
  module MessageSending
    def send_later(method, *args)
      run_at = nil

      if args.last.is_a?(Hash)
        priority = args.last.delete(:priority)
        queue = args.last.delete(:queue)
        run_at = args.last.delete(:run_at)
        if args.last.empty?
          args.pop
        end
      end

      priority ||= DJ_DEFAULT_PRIORITY
      queue ||= DJ_DEFAULT_QUEUE

      if defined?($SYNC) && $SYNC
        send(method, *args)
      else
        job = Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, method.to_sym, args), priority, run_at, queue)
        SchoolAdmin::Delayed.log_job_queued(job)
        job
      end
    end

    def send_at(time, method, *args)
      if defined?($SYNC) && $SYNC
        send(method, *args)
      else
        job = Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, method.to_sym, args), 0, time, nil)
        SchoolAdmin::Delayed.log_job_queued(job)
        job
      end
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
