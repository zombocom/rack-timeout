require_relative "rack/timeout/base"
require_relative "rack/timeout/rails" if defined?(Rails) && Rails.const_defined?(:VERSION) && Rails::VERSION::MAJOR >= 3
