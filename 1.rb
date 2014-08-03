class CrapCutter
  @@wrapped = {}

  def self.wrapped clazz
    @@wrapped[clazz] || []
  end

  UNSAFE_TO_UNDEF = [:method_missing, :const_get, :class, :object_id, :__send__, :__id__, :hash, :respond_to?]

  def self.wrap_methods constant
    instance_methods = @@wrapped[constant] ||= {}

    constant.module_eval do
      def method_missing method, *args
        puts "called #{method} for #{self.class}"
        instance_methods = CrapCutter.wrapped(self.class)
        if instance_methods.include? method
          instance_methods[method].bind(self).call *args
        else
          puts "NOT FOUND!"
          super
        end
      end
    end

    constant.public_instance_methods.each do |method|
      next if UNSAFE_TO_UNDEF.include? method
      # puts "undef #{method} #{method.class}"
      instance_methods[method] = constant.public_instance_method method
      constant.class_eval "undef #{method}"
    end
  end
end

CrapCutter.wrap_methods Float


begin
  Module.constants
    .map { |constant_name| Module.const_get constant_name }
    .select { |constant| constant.is_a? Class }
    .each do |constant|
      puts constant
      puts [constant, constant.public_methods.count].join(' ')
      CrapCutter.wrap_methods constant
      puts "done"
    end
rescue SystemStackError => e
  puts e
  puts caller
end

p 1.2+3
