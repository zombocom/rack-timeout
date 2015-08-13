require_relative "base"

class Rack::Timeout::Railtie < Rails::Railtie
  initializer("rack-timeout.prepend") do |app|
    app.config.middleware.insert_before Rack::Runtime, Rack::Timeout
  end
end
