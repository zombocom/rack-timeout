require_relative "support/namespace"


# This provides compatibility with versions <= 0.3.x where timeout settings were class-level.
# Beware that, unintuitively, a class-level setting overrides local settings for all instances.
# Generally speaking, everyone should migrate to instance-level settings.

module Rack::Timeout::ClassLevelProperties

  module ClassMethods
    attr_accessor :service_timeout, :wait_timeout, :wait_overtime, :service_past_wait
    alias_method :timeout=, :service_timeout=
  end

  module InstanceMethods
    def read_timeout_property_with_class_override property_name
      read_timeout_property self.class.send(property_name), method(property_name).super_method.call
    end

    [:service_timeout, :wait_timeout, :wait_overtime].each do |m|
      define_method(m) { read_timeout_property_with_class_override m }
    end

    def service_past_wait
      self.class.service_past_wait || super
    end
  end

end


Rack::Timeout.extend  Rack::Timeout::ClassLevelProperties::ClassMethods
Rack::Timeout.prepend Rack::Timeout::ClassLevelProperties::InstanceMethods
