require File.join(File.expand_path(File.dirname(__FILE__)), 'rack/timeout')

if defined? Rails
  case Rails::VERSION::MAJOR
  when 2; Rails.configuration.middleware.use Rack::Timeout
  when 3
    class Rack::Timeout::Railtie < Rails::Railtie
      initializer("rack-timeout.insert-rack-timeout") { |app| app.config.middleware.use Rack::Timeout }
    end
  end
end
