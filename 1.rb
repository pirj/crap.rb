require 'set'

class Crap
  UNSAFE = [:const_get, :class, :object_id, :send, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect, :public_instance_method, :public_instance_methods, :nil?, :nonzero?]

  @@calls = {}

  def self.register clazz, method
    clazz_calls = @@calls[clazz] ||= Set.new
    clazz_calls << method
  end

  def self.used clazz, method
    clazz_calls = @@calls[clazz] ||= Set.new
    clazz_calls.delete method
  end

  def self.unused
    @@calls
  end

  def self.wrap constant
    constant.public_instance_methods.each do |method|
      next if UNSAFE.include?(method)
      next if method =~ /^_/
      old_method = :"_#{method}"
      Crap.register constant, method
      constant.class_eval do
        alias_method old_method, method
        define_method(method) do |*args|
          Crap.used self.class, method
          self.send old_method, *args
        end
      end
    end
  end
end

# Module.constants
#   .map { |constant_name| Module.const_get constant_name }
#   .select { |constant| constant.is_a? Class }

# [Object, Module, Class, BasicObject, NilClass, Data, TrueClass, FalseClass, Encoding, String, Symbol, Exception, SystemExit, SignalException, Interrupt, StandardError, TypeError, ArgumentError, IndexError, KeyError, RangeError, ScriptError, SyntaxError, LoadError, NotImplementedError, NameError, NoMethodError, RuntimeError, SecurityError, NoMemoryError, EncodingError, SystemCallError, ZeroDivisionError, FloatDomainError, Numeric, Integer, Fixnum, Float, Bignum, Array, Hash, Struct, RegexpError, Regexp, MatchData, Range, IOError, EOFError, IO, File, Dir, Time, Random, Proc, LocalJumpError, SystemStackError, Method, UnboundMethod, Binding, Enumerator, StopIteration, RubyVM, Thread, ThreadGroup, Mutex, ThreadError, Fiber, FiberError, Rational, Complex, TracePoint, Date, Thread::ConditionVariable, Thread::Queue, Thread::SizedQueue, Monitor, Set, SortedSet]

[Numeric, Integer, Fixnum, Float, Bignum]
  .each do |constant|
    Crap.wrap constant
  end

p 1.2+3

def fib x; return 1 if x < 2; fib(x-1) + fib(x-2); end

p fib(5)

require 'yaml'
File.open('unused.yml', 'w') do |file|
  file.write Crap.unused.inject({}) { |acc, kv| acc[kv.first.name] = kv.last.to_a; acc }.to_yaml
end
