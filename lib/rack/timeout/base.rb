require_relative "core"
require_relative "logging-observer"

Rack::Timeout::StageChangeLoggingObserver.register!
