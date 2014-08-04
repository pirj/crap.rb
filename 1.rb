require 'set'

# # Module.constants
# #   .map { |constant_name| Module.const_get constant_name }
# #   .select { |constant| constant.is_a? Class }

# # [Object, Module, Class, BasicObject, NilClass, Data, TrueClass, FalseClass, Encoding, String, Symbol, Exception, SystemExit, SignalException, Interrupt, StandardError, TypeError, ArgumentError, IndexError, KeyError, RangeError, ScriptError, SyntaxError, LoadError, NotImplementedError, NameError, NoMethodError, RuntimeError, SecurityError, NoMemoryError, EncodingError, SystemCallError, ZeroDivisionError, FloatDomainError, Numeric, Integer, Fixnum, Float, Bignum, Array, Hash, Struct, RegexpError, Regexp, MatchData, Range, IOError, EOFError, IO, File, Dir, Time, Random, Proc, LocalJumpError, SystemStackError, Method, UnboundMethod, Binding, Enumerator, StopIteration, RubyVM, Thread, ThreadGroup, Mutex, ThreadError, Fiber, FiberError, Rational, Complex, TracePoint, Date, Thread::ConditionVariable, Thread::Queue, Thread::SizedQueue, Monitor, RubyLex, StringIO, StringScanner, StringScanner::Error, DateTime, CGI, PrettyPrint, PP, Pry, Slop, Delegator, SimpleDelegator, Tempfile, Pathname, BasicSocket, Socket, SocketError, IPSocket, TCPSocket, TCPServer, UDPSocket, UNIXSocket, UNIXServer, Addrinfo, Tracer, Set, SortedSet, PryRescue, SymbolHash, Insertion, OpenStruct, OptionParser, Logger]

# [Numeric, Integer, Fixnum, Float, Bignum]
#   .each do |constant|
#     # p constant
#     p [constant, constant.public_methods.count].join(' ')
#     CrapCutter.wrap_methods constant
#     p "done"
#   end

# p 1.2+3

UNSAFE = [:const_get, :class, :object_id, :send, :__send__, :__id__, :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect, :public_instance_method, :public_instance_methods, :nil?]

class Crap
  @@calls = {}

  def self.register clazz, method
    clazz_calls = @@calls[clazz] ||= Set.new
    clazz_calls << method
  end

  def self.all
    @@calls
  end
end

[Numeric, Integer, Fixnum, Float, Bignum].each do |constant|
  constant.public_instance_methods.each do |method|
    next if UNSAFE.include?(method)
    next if method =~ /^_/
    old_method = :"_#{method}"
    constant.class_eval do
      alias_method old_method, method
      define_method(method) do |*args|
        Crap.register self.class, method
        self.send old_method, *args
      end
    end
  end
end

p 1.2+3

def fib x; return 1 if x < 2; fib(x-1) + fib(x-2); end

p fib(5)


puts Crap.all
