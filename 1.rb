require 'set'

class Crap
  UNSAFE = [:const_get, :const_missing, :name, :class, :object_id, :send, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect,
            :public_instance_method, :public_instance_methods, :instance_methods, :method,
            :nil?, :nonzero?, :===, :constants, :==, :=~, :'||=', :intern, :new, :[], :inspect,
            :!=, :kind_of?, :!, :untaint, :dup, :instance_variable_set, # MSpec specific: throw away
            :backtrace, :message, :exception, :set_backtrace, # Exceptions specific
            :delete, :include?, # Array specific
            :p, :load, :require, # Kernel specific
            :include, :const_defined?, # Module specific
            :extend, :singleton_methods, # Object specific
            :to_i, # Integer specific
            :round, # Fixnum specific
  ]

  UNSAFE_CONSTANTS = [ IO, File, Dir, Proc, LocalJumpError, SystemStackError, Method, UnboundMethod, Binding, StopIteration, RubyVM, Thread, ThreadGroup, Mutex, Monitor, ThreadError, Fiber, FiberError, TracePoint, Thread::ConditionVariable, Thread::Queue, Thread::SizedQueue]

  @@wrapped = {}

  def self.register clazz, method
    clazz_wrapped = @@wrapped[clazz] ||= Set.new
    clazz_wrapped << method
  end

  def self.used clazz, method
    # p ['used', clazz, method]
    clazz_wrapped = @@wrapped[clazz]
    clazz_wrapped.delete method
    unwrap_method clazz, method
  end

  def self.unused
    @@wrapped
  end

  def self.wrap constant
    return if UNSAFE_CONSTANTS.include? constant
    constant.public_instance_methods.each do |method|
      next if UNSAFE.include? method
      next if method =~ /^_/
      wrap_method constant, method
    end
  end

  def self.wrap_method constant, method
    old_method = :"_#{method}"
    register constant, method
    constant.class_eval do
      alias_method old_method, method
      # p ['wrapping', constant, method]
      define_method(method) do |*args, &block|
        # p ['called', constant, method]
        # p [constant, method, args.inspect, block.inspect].join '#'
        Crap.used self.class, method
        self.send old_method, *args, &block
      end
    end
  end

  # This method allows wrapping unsafe constants too
  def self.unwrap_method constant, method
    unless constant.instance_methods.include? method
      # p ['wtf', constant, method]
      return
    end
    # p ['undef', constant, method]
    constant.class_eval <<-EVAL
      undef #{method}
      old_method = :"_#{method}"
      alias_method method, old_method
    EVAL
  end
end

Module.constants
  .map { |constant_name| Module.const_get constant_name }
  .select { |constant| constant.is_a? Class }
  .each do |constant|
    Crap.wrap constant
  end

require 'mspec/commands/mspec'
script = MSpecMain.new
script.load_default
# script.load '~/.mspecrc'
script.options
script.signals
script.register
script.run

File.open('unused.yml', 'w') do |file|
  Crap.unused.each do |clazz, methods|
    file.write "#{clazz.name}:\n"
    methods.each do |method|
      file.write " - #{method}\n"
    end
  end
end
