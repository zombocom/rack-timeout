require_relative "base"

class Rack::Timeout::Railtie < Rails::Railtie
  initializer("rack-timeout.prepend") do |app|
    next if Rails.env.test?

    middleware = Rails::VERSION::MAJOR >= 6 ? app.middleware : app.config.middleware

    if defined?(ActionDispatch::RequestId)
      middleware.insert_after(ActionDispatch::RequestId, Rack::Timeout)
    else
      middleware.insert_before(Rack::Runtime, Rack::Timeout)
    end
  end
end