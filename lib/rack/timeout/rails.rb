require_relative "base"

class Rack::Timeout::Railtie < Rails::Railtie
  initializer('rack-timeout.prepend') { |app| app.config.middleware.insert 0, Rack::Timeout }
end
