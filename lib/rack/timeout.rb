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
      raise RequestDroppedByRouterError if Time.now - request_start > 30
      ::Timeout.timeout(self.class.timeout, ::Rack::Timeout::Error) { @app.call(env) }
    end

  end
end
