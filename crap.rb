require 'set'

module Crap
  # TODO: separate this to clean up even more crap
  UNSAFE = [:const_get, :const_missing, :name, :class, :object_id, :send, :__send__, :__id__,
            :hash, :respond_to?, :module_eval, :class_eval, :to_s, :inspect,
            :public_instance_method, :public_instance_methods, :instance_methods, :method,
            :nil?, :nonzero?, :===, :constants, :==, :=~, :'||=', :intern, :new, :[], :inspect,
            :[]=, # Hash specific
            :<<, # Set specific
            :backtrace, :message, :exception, :set_backtrace, # Exceptions specific
            :delete, :include?, # Array specific
            :p, :load, :require, # Kernel specific
            :include, :const_defined?, # Module specific
            :extend, :singleton_methods, # Object specific
            :method_added, # Class specific
            :to_i, # Integer specific
            :round, :<, :-, :+ # Fixnum specific
  ]

  UNSAFE_CONSTANTS = [ IO, File, Dir, Proc, LocalJumpError, SystemStackError, Method, UnboundMethod, Binding, StopIteration, RubyVM, Thread, ThreadGroup, Mutex, Monitor, ThreadError, Fiber, FiberError, TracePoint, Thread::ConditionVariable, Thread::Queue, Thread::SizedQueue]

  class Analyzer
    @@wrapped = {}
    @@used = {}

    class << self
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
        clazz.public_instance_methods.each do |method|
          wrap_method clazz, method
        end
      end

      def wrap_method clazz, method
        return if UNSAFE_CONSTANTS.include? clazz
        return if UNSAFE.include? method
        return if method =~ /^_/
        return if used? clazz, method
        return if wrapped? clazz, method

        wrapped(clazz) << method

        old_method = :"_#{method}"
        # p ['wrapping', clazz, method]
        clazz.class_eval do
          alias_method old_method, method
          define_method(method) do |*args, &block|
            # p ['called', clazz, method]
            Crap::Analyzer.called self.class, method
            self.send old_method, *args, &block
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
    end
  end

  class Cleaner
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
        clazz.public_instance_methods.each do |method|
          clean_method clazz, method
        end
      end

      def clean_method clazz, method
        return if UNSAFE_CONSTANTS.include? clazz
        return if UNSAFE.include? method
        return if method =~ /^_/
        return unless unused(clazz).include? method
        return unless clazz.public_instance_methods.include? method

        # p ['clean', clazz, method]
        clazz.class_eval <<-EVAL
          undef #{method}
        EVAL
      end

    private

      def unused clazz
        @@unused[clazz] ||= Set.new
      end
    end
  end
end
