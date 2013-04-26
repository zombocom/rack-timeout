# encoding: utf-8
require 'timeout'

module Rack
  class Timeout
    class Error < RuntimeError;        end
    class RequestTooOldError  < Error; end
    class RequestAbortedError < Error; end

    @timeout = 15
    class << self
      attr_accessor :timeout
    end

    def initialize(app)
      @app = app
    end

    MAX_REQUEST_AGE = 30 # seconds
    def call(env)
      request_start = env['HTTP_X_REQUEST_START'] # unix timestamp in ms
      request_start = Time.at(request_start.to_i / 1000) if request_start
      request_age   = Time.now - request_start           if request_start
      time_left     = MAX_REQUEST_AGE - request_age      if request_age
      timeout       = [self.class.timeout, time_left].compact.min

      env['rack-timeout.request-age'] = request_age
      env['rack-timeout.timeout']     = timeout if timeout > 0

      if timeout <= 0
        Rack::Timeout.set_state_and_log! env, :dropped
        raise RequestTooOldError
      end

      Rack::Timeout.set_state_and_log! env, :ready
      ::Timeout.timeout(timeout, RequestAbortedError) do
        ready_time = Time.now
        response = @app.call(env)
        env['rack-timeout.duration'] = Time.now - ready_time
        Rack::Timeout.set_state_and_log! env, :completed
        response
      end
    end

    FINAL_STATES = [:dropped, :aborted, :completed]
    def self.set_state_and_log!(env, state)
      env["rack-timeout.state"] = state unless FINAL_STATES.include? env["rack-timeout.state"]

      id, state              = env.values_at(*%w[ HTTP_HEROKU_REQUEST_ID rack-timeout.state ])
      age, timeout, duration = env.values_at(*%w[ rack-timeout.request-age rack-timeout.timeout rack-timeout.duration ])
                                .map { |s| "%.fms" % (s * 1000) if s }

      s = "rack-timeout:"
      s << " id="       << id         if id
      s << " age="      << age        if age
      s << " timeout="  << timeout    if timeout
      s << " duration=" << duration   if duration
      s << " state="    << state.to_s if state
      s << "\n"
      $stderr << s
    end

    class AbortionReporter
      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      rescue Rack::Timeout::RequestAbortedError
        Rack::Timeout.set_state_and_log!(env, :aborted)
        raise
      end
    end

  end
end
