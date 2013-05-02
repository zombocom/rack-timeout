# encoding: utf-8
require 'rack/timeout'

if defined?(Rails) && [3,4].include?(Rails::VERSION::MAJOR)
  class Rack::Timeout::Railtie < Rails::Railtie
    initializer('rack-timeout.prepend') { |app| app.config.middleware.insert 0, Rack::Timeout }
    initializer('rack-timeout.tracker') { |app| app.config.middleware.use Rack::Timeout::TimeoutTracker }
  end
end
