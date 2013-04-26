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
        log env, "dropped"
        raise RequestTooOldError
      end

      log env, "starting"
      ::Timeout.timeout(timeout, RequestAbortedError) do
        t0 = Time.now
        rv = @app.call(env)
        td = Time.now - t0
        env['rack-timeout.completed'] = td
        log env
        rv
      end
    end

    private

    def log(env, msg=nil)
      id, age, timeout, completed = env.values_at \
        *%w[ HTTP_HEROKU_REQUEST_ID rack-timeout.request-age rack-timeout.timeout rack-timeout.completed ]
      s = "rack-timeout:"
      s << " id="        << id if id
      s << " age="       << ms(age) if age
      s << " timeout="   << ms(timeout) if timeout
      s << " completed=" << ms(completed) if completed
      s << " "           << msg if msg
      s << "\n"
      $stderr << s
    end

    def ms(s)
      "%.fms" % (s * 1000) if s
    end

  end
end
