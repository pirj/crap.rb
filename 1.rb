require 'set'

class Crap
  UNSAFE = [:const_get, :const_missing, :name, :class, :object_id, :send, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect,
            :public_instance_method, :public_instance_methods, :instance_methods, :method,
            :nil?, :nonzero?, :===, :constants, :==, :=~, :'||=', :intern, :new, :[], :inspect,
            :backtrace, :message, :exception, :set_backtrace, # Exceptions specific
            :delete, # Array specific
            :include?, # Array specific
            :p, # Kernel specific
            :round, # Fixnum specific
  ]

  @@wrapped = {}

  def self.register clazz, method
    clazz_wrapped = @@wrapped[clazz] ||= Set.new
    clazz_wrapped << method
  end

  def self.used clazz, method
    p ['used', clazz, method]
    clazz_wrapped = @@wrapped[clazz]
    clazz_wrapped.delete method
    unwrap_method clazz, method
  end

  def self.unused
    @@wrapped
  end

  def self.wrap constant
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
        # p [constant, method, args.inspect, block.inspect].join '#'
        Crap.used self.class, method
        self.send old_method, *args, &block
      end
    end
  end

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

# Module.constants
#   .map { |constant_name| Module.const_get constant_name }
#   .select { |constant| constant.is_a? Class }

# [Object, Module, Class, BasicObject, NilClass, Data, TrueClass, FalseClass, Encoding, String, Symbol, Exception, SystemExit, SignalException, Interrupt, StandardError, TypeError, ArgumentError, IndexError, KeyError, RangeError, ScriptError, SyntaxError, LoadError, NotImplementedError, NameError, NoMethodError, RuntimeError, SecurityError, NoMemoryError, EncodingError, SystemCallError, ZeroDivisionError, FloatDomainError, Numeric, Integer, Fixnum, Float, Bignum, Array, Hash, Struct, RegexpError, Regexp, MatchData, Range, IOError, EOFError, Enumerator, Rational, Complex, Date, Set, SortedSet, Time, Random, 
#! IO, File, Dir, Proc, LocalJumpError, SystemStackError, Method, UnboundMethod, Binding,
#! StopIteration, RubyVM, Thread, ThreadGroup, Mutex, Monitor,
#! ThreadError, Fiber, FiberError,
#! TracePoint,
#! Thread::ConditionVariable, Thread::Queue, Thread::SizedQueue,
# ]

 
[Object, Module, Class, BasicObject, NilClass, Data, TrueClass, FalseClass, Encoding, String, Symbol, Exception, SystemExit, SignalException, Interrupt, StandardError, TypeError, ArgumentError, IndexError, KeyError, RangeError, ScriptError, SyntaxError, LoadError, NotImplementedError, NameError, NoMethodError, RuntimeError, SecurityError, NoMemoryError, EncodingError, SystemCallError, ZeroDivisionError, FloatDomainError, Numeric, Integer, Fixnum, Float, Bignum, RegexpError, Regexp, MatchData, Range, IOError, EOFError, Enumerator, Rational, Complex, Date, Set, SortedSet, Time, Random, Struct, Hash, Array
].each do |constant|
    Crap.wrap constant
  end

p 1.2+3

def fib x; return 1 if x < 2; fib(x-1) + fib(x-2); end

p fib(5)

p Time.now

File.open('unused.yml', 'w') do |file|
  Crap.unused.each do |clazz, methods|
    file.write "#{clazz.name}:\n"
    methods.each do |method|
      file.write " - #{method}\n"
    end
  end
end
