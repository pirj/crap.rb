require 'set'

module Crap
  module Unsafe
    def safe? clazz, method
      return false if method =~ /^_/
      return false if UNSAFE_CONSTANTS.include? clazz
      return false if clazz.name.nil? # Singleton class?
      return false if UNSAFE[clazz] && UNSAFE[clazz].include?(method)
      return false if UNSAFE_NONDEFAULT[clazz.name.to_sym] && UNSAFE[clazz.name.to_sym].include?(method)
      # return false if UNSAFE_ALL.include? method
      return false if method =~ /[-\+\^<>%@\*~\/]/
      # p ['safe to', clazz, method]
      true
    end

    UNSAFE = {
      Module =>      [ :autoload, :singleton_class?, :protected_instance_methods, :include, :const_defined?,
                       :const_get, :const_missing, :name, :module_eval, :class_eval, :to_s, :inspect,
                       :public_instance_method, :public_instance_methods, :instance_methods, :===, :constants,
                       :== ],
      Kernel =>      [ :p, :load, :require ],
      BasicObject => [ :__send__, :__id__, :==],
      NilClass =>    [ :to_s, :inspect, :nil?],
      TrueClass =>   [ :to_s, :inspect],
      FalseClass =>  [ :to_s, :inspect],
      Object =>      [ :!=, :kind_of?, :!, :taint, :instance_exec, :extend, :singleton_methods ],
      Class =>       [ :method_added, :public_instance_methods, :instance_methods, :new],
      String =>      [ :replace , :hash, :to_s, :===, :==, :=~, :intern, :[], :inspect],
      Symbol =>      [ :to_s, :===, :==, :=~, :intern, :[], :inspect],
      Encoding =>    [ :name, :to_s, :inspect ],
      Array =>       [ :each_slice, :delete, :include? , :hash, :to_s, :==, :[], :inspect],
      Hash =>        [ :has_key?, :[]=, :delete , :hash, :to_s, :==, :[], :inspect],
      Set =>         [ :<<, :delete, :hash, :==, :inspect],
      Exception =>   [ :backtrace, :message, :exception, :set_backtrace , :respond_to?, :to_s, :respond_to?, :to_s, :==, :inspect],
      NameError =>   [ :name],
      Integer =>     [ :to_i ],
      Numeric =>     [ :nonzero?],
      Fixnum =>      [ :round, :<, :-, :+, :to_s, :===, :==, :[], :inspect],
      Float =>       [ :hash, :to_s, :===, :==, :inspect],
      Bignum =>      [ :hash, :to_s, :===, :==, :[], :inspect],
      Struct =>      [ :hash, :to_s, :==, :[], :inspect],
      Regexp =>      [ :hash, :to_s, :===, :==, :=~, :inspect],
      MatchData =>   [ :hash, :to_s, :==, :[], :inspect],
      Range =>       [ :hash, :to_s, :===, :==, :inspect],
      IO =>          [ :inspect],
      Dir =>         [ :inspect],
      Date =>        [ :hash, :to_s, :===, :inspect],
      Time =>        [ :hash, :to_s, :inspect],
      Random =>      [ :==],
      Proc =>        [ :hash, :to_s, :===, :[], :inspect],
      Method =>      [ :name, :hash, :to_s, :==, :[], :inspect],
      UnboundMethod => [ :name, :hash, :to_s, :==, :inspect],
      Enumerator =>  [ :inspect],
      Thread =>      [ :inspect, :[]],
      Rational =>    [ :hash, :to_s, :==, :inspect],
      Complex =>     [ :hash, :to_s, :==, :inspect],
      TracePoint =>  [ :inspect],
    }

    UNSAFE_NONDEFAULT = {
      :StringScanner => [ :[], :inspect],
      :DateTime =>    [ :to_s],
      :Slop =>        [ :to_s, :[]],
      :Delegator =>   [ :==],
      :Tempfile =>    [ :inspect],
      :Pathname =>    [ :hash, :to_s, :===, :==, :inspect],
      :BasicSocket => [ :send],
      :UDPSocket =>   [ :send],
      :Addrinfo =>    [ :to_s, :inspect],
      :SymbolHash =>  [ :[]],
      :OpenStruct =>  [ :hash, :to_s, :==, :[], :inspect],
      :OptionParser => [ :to_s, :new]
    }

    UNSAFE_CONSTANTS = [ IO, File, Dir, Proc, LocalJumpError, SystemStackError, Method, UnboundMethod, Binding,
                         StopIteration, RubyVM, Thread, ThreadGroup, Mutex, Monitor, ThreadError, Fiber,
                         FiberError, TracePoint, Thread::ConditionVariable, Thread::Queue, Thread::SizedQueue ]
  end

  class Analyzer
    extend Unsafe

    @@wrapped = {}
    @@used = {}
    @@ignore = Set.new

    class << self
      def ignore clazz
        @@ignore << clazz
      end

      def wrap_all
        Module.constants
          .map { |constant_name| Module.const_get constant_name rescue nil } # wtf why crap.rb:45:in `const_get': uninitialized constant Module::UNSAFE
          .select { |constant| constant.is_a? Class }
          .each do |clazz|
            wrap clazz
        end
      end

      def wrap_dog
        Class.class_eval do
          def method_added method
            # p "#{method} added to #{self}"
            Crap::Analyzer.wrap_method self, method
          end
        end

        Object.class_eval do
          def self.inherited base
            super
            # p "new class added #{base}"
            Crap::Analyzer.wrap base
          end
        end
      end

      def save path
        File.open(path, 'w') do |file|
          @@wrapped.each do |clazz, methods|
            file.write "#{clazz.name}:\n"
            methods.each do |method|
              file.write " - #{method}\n"
            end
          end
        end
      end

    # protected # Why doesn't defining a method in class_eval count as local lexical scope? Hmmm

      def wrap clazz
        clazz.instance_methods(false).each do |method|
          wrap_method clazz, method
        end
      end

      def wrap_method clazz, method
        return unless safe? clazz, method
        return if @@ignore.include? clazz.name.to_sym
        return if used? clazz, method
        return if wrapped? clazz, method

        wrapped(clazz) << method

        old_method = :"_#{method}"
        # p ['wrapping', clazz, method]
        clazz.class_eval do
          alias_method old_method, method
          define_method(method) do |*args, &block|
            # p ['called', clazz, method]
            Crap::Analyzer.called clazz, method
            self.send method, *args, &block
          end
        end
      end

      def called clazz, method
        # p ['called', clazz, method]
        wrapped(clazz).delete method
        unwrap_method clazz, method
      end

    private

      def used? clazz, method
        used(clazz).include?(method)
      end

      def wrapped? clazz, method
        wrapped(clazz).include?(method)
      end

      def wrapped clazz
        @@wrapped[clazz] ||= Set.new
      end

      def used clazz
        @@used[clazz] ||= Set.new
      end

      def unwrap_method clazz, method
        used(clazz) << method
        # p ['unwrap', clazz, method]
        old_method = "_#{method}"
        clazz.class_eval do
          remove_method method
          alias_method method, old_method
          undef_method old_method
        end
      end
    end
  end

  class Cleaner
    extend Unsafe

    class << self
      def clean_dog
        Class.class_eval do
          def method_added method
            # p "#{method} added to #{self}"
            Crap::Cleaner.clean_method self, method
          end
        end

        Object.class_eval do
          def self.inherited base
            super
            # p "new class added #{base}"
            Crap::Cleaner.clean base
          end
        end
      end

      def clean_all
        @@unused.each do |clazz, methods|
          methods.each do |method|
            clean_method clazz, method
          end
        end
      end

      def load path
        @@unused = {}
        current_clazz = nil
        File.open(path) do |file|
          while !file.eof? do
            line = file.readline.chomp
            if line.end_with? ':'
              current_clazz = Module.const_get line[0..-2]
            else
              unused(current_clazz) << line[3..-1].to_sym
            end
          end
        end
      end

    # protected

      def clean clazz
        clazz.instance_methods(false).each do |method|
          clean_method clazz, method
        end
      end

      def clean_method clazz, method
        return unless safe? clazz, method

        return unless unused(clazz).include? method
        # TODO: method_defined?
        return unless clazz.instance_methods(false).include? method

        # p ['clean', clazz, method]
        # TODO!!! Only remove if defined here, not by parent only. check A#methods: from pry
        clazz.class_eval do
          remove_method method
        end
      end

    private

      def unused clazz
        @@unused[clazz] ||= Set.new
      end
    end
  end
end
