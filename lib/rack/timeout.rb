require RUBY_VERSION < '1.9' ? 'system_timer' : 'timeout'
SystemTimer ||= Timeout

module Rack
  class Timeout
    @timeout = 15
    class << self
      attr_accessor :timeout
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      SystemTimer.timeout(self.class.timeout, ::Timeout::Error) { @app.call(env) }
    end

  end
end
