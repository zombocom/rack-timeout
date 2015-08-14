require_relative "core"

# Groups timeout exceptions in rollbar by exception class, http method, and url.
# Usage: after requiring rollbar, call:
#   require "rack/timeout/rollbar"

module Rack::Timeout::Rollbar
  def build_payload(level, message, exception, extra)
    payload = super(level, message, exception, extra)

    return payload unless exception.is_a? ::Rack::Timeout::ExceptionWithEnv
    return payload unless payload.respond_to? :[]

    data = payload["data"]
    return data unless data.respond_to? :[]=

    request = ::Rack::Request.new(exception.env)

    data["fingerprint"] = [
      exception.class.name,
      request.request_method,
      request.fullpath
      ].join(" ")

    return payload
  end
end

::Rollbar::Notifier.prepend ::Rack::Timeout::Rollbar
