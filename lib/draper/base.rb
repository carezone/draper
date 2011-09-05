module Draper
  class Base
    require 'active_support/core_ext/class/attribute'
    class_attribute :denied, :allowed, :serialize_spec, :model_class
    attr_accessor :context, :model

    DEFAULT_DENIED = Object.new.methods << :method_missing
    FORCED_PROXY = [:to_param]
    self.denied = DEFAULT_DENIED

    def initialize(input, context = {})
      input.inspect
      self.class.model_class = input.class if model_class.nil?
      @model = input
      self.context = context
      build_methods
    end

    def self.find(input)
      self.new(model_class.find(input))
    end

    def self.decorates(input)
      self.model_class = input.to_s.classify.constantize
      model_class.send :include, Draper::ModelSupport
    end

    def self.denies(*input_denied)
      raise ArgumentError, "Specify at least one method (as a symbol) to exclude when using denies" if input_denied.empty?
      raise ArgumentError, "Use either 'allows' or 'denies', but not both." if self.allowed?
      self.denied += input_denied
    end

    def self.allows(*input_allows)
      raise ArgumentError, "Specify at least one method (as a symbol) to allow when using allows" if input_allows.empty?
      raise ArgumentError, "Use either 'allows' or 'denies', but not both." unless (self.denied == DEFAULT_DENIED)
      self.allowed = input_allows
    end

    def self.serializes(*serialize_spec)
      methods = {}
      literals = {}

      serialize_spec.each do |spec|
        case spec
        when Symbol
          methods[spec] = spec
        when Hash
          spec.each_pair do |k, v|
            if v.is_a?(Symbol)
              methods[k] = v
            else
              literals[k] = v.as_json
            end
          end
        else
          raise ArgumentError, "#{spec.inspect} is invalid. Specify :attr, {:attr => :model_attr}, or {:attr => 'literal'}."
        end
      end

      self.serialize_spec = {:methods => methods, :literals => literals}
    end

    def as_json(options = nil)
      spec = self.serialize_spec
      return super unless spec

      unless !options || (options.keys & [:only, :except, :methods]).empty?
        raise ArgumentError, "No options are supported for Draper::Base.as_json"
      end

      json = {}
      spec[:methods].each_pair { |k, v| json[k] = send(v).as_json }
      json.merge!(spec[:literals])
    end

    def self.decorate(input, context = {})
      input.respond_to?(:each) ? input.map{|i| new(i, context)} : new(input, context)
    end

    def helpers
      @helpers ||= ApplicationController::all_helpers
    end
    alias :h :helpers

    def self.lazy_helpers
      self.send(:include, Draper::LazyHelpers)
    end

    def self.model_name
      ActiveModel::Name.new(model_class)
    end

    def to_model
      @model
    end

  private
    def select_methods
      specified = self.allowed || (model.public_methods.map{|s| s.to_sym} - denied.map{|s| s.to_sym})
      (specified - self.public_methods.map{|s| s.to_sym}) + FORCED_PROXY
    end

    def build_methods
      select_methods.each do |method|
        (class << self; self; end).class_eval do
          define_method method do |*args, &block|
            model.send method, *args, &block
          end
        end
      end
    end
  end
end
