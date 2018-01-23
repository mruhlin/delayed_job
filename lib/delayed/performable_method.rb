class Class
  def load_for_delayed_job(id)
    if id && self.respond_to?(:find)
      find(id)
    else
      self
    end
  end
  
  def dump_for_delayed_job
    name
  end
end

module Delayed
  class PerformableMethod < Struct.new(:object, :method, :args)
    #STRING_FORMAT = /^LOAD\;([A-Z][\w\:]+)(?:\;(\w+))?$/
    #[terry] allow dashes for guids
    STRING_FORMAT = /^LOAD\;([A-Z][\w\:]+)(?:\;([\w\-]+))?$/
    
    class LoadError < StandardError
    end

    def initialize(object, method, args)
      raise NoMethodError, "undefined method `#{method}' for #{object.inspect}" unless object.respond_to?(method)

      self.object = dump(object)
      self.args   = args.map { |a| dump(a) }
      self.method = method.to_sym
    end
    
    def display_name
      if STRING_FORMAT === object
        "#{$1}#{$2 ? '#' : '.'}#{method}"
      else
        "#{object.class}##{method}"
      end
    end
    
    def perform
      if customer.nil?
        loaded_object.send(method, *loaded_args)
      else
        System.with_customer(customer) do
          loaded_object.send(method, *loaded_args)
        end
      end
    rescue PerformableMethod::LoadError
      # We cannot do anything about objects that can't be loaded
      true
    end

    def customer
      return @customer if defined?(@customer)
      entity = ([loaded_object] + loaded_args).detect { |o| o.respond_to?(:customer_id) && o.try(:customer_id) }
      @customer = entity ? Customer.find_by_id(entity.customer_id) : nil
    rescue PerformableMethod::LoadError
      nil
    end

    private

    def loaded_object
      @loaded_object ||= load(object)
    end

    def loaded_args
      @loaded_args ||= args.map { |a| load(a) }
    end

    def load(obj)
      if STRING_FORMAT === obj
        $1.constantize.load_for_delayed_job($2)
      else
        obj
      end
    rescue => e
      raise PerformableMethod::LoadError
    end

    def dump(obj)
      if obj.respond_to?(:dump_for_delayed_job)
        "LOAD;#{obj.dump_for_delayed_job}"
      else
        obj
      end
    end
  end
end
