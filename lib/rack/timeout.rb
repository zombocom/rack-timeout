# encoding: utf-8
require 'timeout'

module Rack
  class Timeout
    class Error < ::Timeout::Error; end
    class RequestDroppedByRouterError < RuntimeError; end

    @timeout = 15
    class << self
      attr_accessor :timeout
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      request_start = env["HTTP_X_REQUEST_START"] # Unix timestamp in ms
      request_start &&= Time.at request_start.to_i / 1000.0
      request_age = Time.now - request_start
      time_left = 30 - request_age
      raise RequestDroppedByRouterError if time_left < 0
      timeout = [self.class.timeout, time_left].min
      ::Timeout.timeout(timeout, ::Rack::Timeout::Error) { @app.call(env) }
    end

  end
end
