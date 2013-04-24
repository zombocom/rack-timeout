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
      '%05.2f' % n
    end

    def call(env)
      request_id      = env['HTTP_HEROKU_REQUEST_ID'].to_s[0, 6]
      request_start   = env["HTTP_X_REQUEST_START"] # Unix timestamp in ms
      request_start &&= Time.at request_start.to_i / 1000.0
      request_age     = Time.now - request_start
      time_left       = 30 - request_age
      if time_left < 0
        $stderr.puts "rack-timeout: id=#{request_id} age=#{f request_age} aborted, too old"
        raise RequestDroppedByRouterError
      end
      timeout = [self.class.timeout, time_left].min
      $stderr.puts "rack-timeout: id=#{request_id} age=#{f request_age} timeout=#{f timeout}"
      ::Timeout.timeout(timeout, ::Rack::Timeout::Error) do
        t0 = Time.now
        retval = @app.call(env)
        t1 = Time.now
        td = t1 - t0
        $stderr.puts "rack-timeout: id=#{request_id} age=#{f request_age} timeout=#{f timeout} completed=#{f td}"
        retval
      end
    end

  end
end
