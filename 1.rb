# require 'pry'

class CrapCutter
  @@wrapped = {}

  def self.wrapped clazz
    @@wrapped[clazz] || []
  end

  UNSAFE_TO_UNDEF = {
    Module => [:method_missing, :const_get, :class, :object_id, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect, :public_instance_method, :public_instance_methods],
    Object => [:method_missing, :const_get, :class, :object_id, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect],
    Class => [:method_missing, :const_get, :class, :object_id, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect, :public_instance_method, :public_instance_methods, :instance_methods],
    Binding => #[:method_missing, :instance_variable_set]
    [:method_missing, :const_get, :class, :object_id, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect, :public_instance_method, :public_instance_methods],
    BasicObject => [:method_missing, :const_get, :class, :object_id, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect, :public_instance_method, :public_instance_methods],
  }

  UNSAFE_ALL = [:method_missing, :const_get, :class, :object_id, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect, :public_instance_method, :public_instance_methods, :nil?]

  def self.wrap_methods constant
    constant.module_eval do
      # todo: define_method, alias, check if method_missing is present to prevent stack overflow

      if self.instance_methods.include? :method_missing
        def method_missing method, *args
          # p "called #{method.inspect} for #{self}"
          instance_methods = CrapCutter.wrapped(self.class)
          if instance_methods.include? method
            instance_methods[method].bind(self).call *args
          else
            p "NOT FOUND!"
            super
          end
        end
      else
        define_method :method_missing do |method, *args|
          # p "2called #{method.inspect} for #{self} #{self.class}"
          instance_methods = CrapCutter.wrapped(self.class)
          fail NoMethodError, method if instance_methods.include? method
          instance_methods[method].bind(self).call *args
        end
      end
    end

    unsafe = UNSAFE_TO_UNDEF[constant] || []
    # binding.pry
    p [constant, unsafe].join ' '

    instance_methods = @@wrapped[constant] ||= {}

    constant.public_instance_methods.each do |method|
      next if !unsafe.nil? && unsafe.include?(method)
      next if UNSAFE_ALL.include? method
      p "undef #{method}"
      instance_methods[method] = constant.public_instance_method method
      constant.class_eval "undef #{method}"
    end
  end
end

CrapCutter.wrap_methods Float


Module.constants
  .map { |constant_name| Module.const_get constant_name }
  .select { |constant| constant.is_a? Class }
  .each do |constant|
    # p constant
    p [constant, constant.public_methods.count].join(' ')
    CrapCutter.wrap_methods constant
    p "done"
  end

p 1.2+3
