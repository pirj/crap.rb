require 'set'

class Crap
  UNSAFE = [:const_get, :const_missing, :name, :class, :object_id, :send, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect,
            :public_instance_method, :public_instance_methods, :instance_methods, :method,
            :nil?, :nonzero?, :===, :constants, :==, :=~, :'||=', :intern, :new, :[], :inspect,
            :[]=, # Hash specific
            :<<, # Set specific
            :!=, :kind_of?, :!, :untaint, :dup, :instance_variable_set, # MSpec specific: throw away
            :backtrace, :message, :exception, :set_backtrace, # Exceptions specific
            :delete, :include?, # Array specific
            :p, :load, :require, # Kernel specific
            :include, :const_defined?, # Module specific
            :extend, :singleton_methods, # Object specific
            :method_added, # Class specific
            :to_i, # Integer specific
            :round, # Fixnum specific
  ]

  UNSAFE_CONSTANTS = [ IO, File, Dir, Proc, LocalJumpError, SystemStackError, Method, UnboundMethod, Binding, StopIteration, RubyVM, Thread, ThreadGroup, Mutex, Monitor, ThreadError, Fiber, FiberError, TracePoint, Thread::ConditionVariable, Thread::Queue, Thread::SizedQueue]
  UNSAFE_OPTIONAL_CONSTANTS = [ :MSpecMain, :MSpecScript ]

  @@wrapped = {}
  @@used = {}

  def self.used clazz, method
    # p ['used', clazz, method]
    @@wrapped[clazz].delete method
    unwrap_method clazz, method
  end

  def self.used? clazz, method
    @@used[clazz] && @@used[clazz].include?(method)
  end

  def self.wrapped? clazz, method
    @@wrapped[clazz] && @@wrapped[clazz].include?(method)
  end

  def self.unused
    @@wrapped
  end

  def self.wrap_all
    Module.constants
      .map { |constant_name| Module.const_get constant_name rescue nil } # wtf why crap.rb:45:in `const_get': uninitialized constant Module::UNSAFE
      .select { |constant| constant.is_a? Class }
      .each do |clazz|
        wrap clazz
    end
  end

  def self.wrap clazz
    clazz.public_instance_methods.each do |method|
      wrap_method clazz, method
    end
  end

  def self.wrap_method clazz, method
    return if UNSAFE_CONSTANTS.include? clazz
    return if UNSAFE_OPTIONAL_CONSTANTS.include? clazz.name.to_sym
    return if UNSAFE.include? method
    return if method =~ /^_/
    return if used? clazz, method
    return if wrapped? clazz, method

    clazz_wrapped = @@wrapped[clazz] ||= Set.new
    @@used[clazz] ||= Set.new
    clazz_wrapped << method

    old_method = :"_#{method}"
    # p ['wrapping', clazz, method]
    clazz.class_eval do
      alias_method old_method, method
      define_method(method) do |*args, &block|
        # p ['called', clazz, method]
        # p [clazz, method, args.inspect, block.inspect].join '#'
        Crap.used self.class, method
        self.send old_method, *args, &block
      end
    end
  end

  def self.unwrap_method clazz, method
    @@used[clazz] << method
    unless clazz.instance_methods.include? method
      # p ['wtf', clazz, method]
      return
    end
    # p ['unwrap', clazz, method]
    clazz.class_eval <<-EVAL
      undef #{method}
      old_method = :"_#{method}"
      alias_method method, old_method
    EVAL
  end

  def self.wrap_dog
    Class.class_eval do
      def method_added method
        # p "#{method} added to #{self}"
        Crap.wrap_method self, method
      end
    end

    Object.class_eval do
      def self.inherited base
        super
        # p "new class added #{base}"
        Crap.wrap base
      end
    end
  end

  def self.save path
    File.open(path, 'w') do |file|
      unused.each do |clazz, methods|
        file.write "#{clazz.name}:\n"
        methods.each do |method|
          file.write " - #{method}\n"
        end
      end
    end
  end

  def self.load path
    File.open(path) do |file|
      file.readline
      unused.each do |clazz, methods|
        file.write "#{clazz.name}:\n"
        methods.each do |method|
          file.write " - #{method}\n"
        end
      end
    end
  end

  def self.cut
    unused.each do |clazz, methods|
      methods.each do |method|
        clazz.class_eval <<-EVAL
          undef #{method}
        EVAL
      end
    end
  end
end
