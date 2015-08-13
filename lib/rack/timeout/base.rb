require_relative "core"
require_relative "logging-observer"

Rack::Timeout::StateChangeLoggingObserver.register!
