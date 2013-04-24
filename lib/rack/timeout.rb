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

    def f n
      '%.2f' % n
    end

    def call(env)
      request_id      = env['HTTP_HEROKU_REQUEST_ID']
      request_start   = env["HTTP_X_REQUEST_START"] # Unix timestamp in ms
      request_start &&= Time.at request_start.to_i / 1000.0
      request_age     = request_start ? Time.now - request_start : 0
      time_left       = 30 - request_age
      log             = lambda { |s| $stderr.puts "rack-timeout: id=#{request_id} age=#{f request_age} #{s}"}
      timeout         = [self.class.timeout, time_left].min
      (log.call "dropped"; raise RequestDroppedByRouterError) if time_left < 0
      log.call "timeout=#{f timeout} starting"
      ::Timeout.timeout(timeout, ::Rack::Timeout::Error) do
        t0 = Time.now
        rv = @app.call(env)
        td = Time.now - t0
        log.call "timeout=#{f timeout} completed=#{f td}"
        rv
      end
    end

  end
end
