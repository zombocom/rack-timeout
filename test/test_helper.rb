require "test/unit"
require "rack/test"
require "rack-timeout"

class RackTimeoutTest < Test::Unit::TestCase
  include Rack::Test::Methods

  attr_accessor :settings

  def initialize(*args)
    self.settings ||= {}
    super(*args)
  end

  def app
    settings = self.settings
    Rack::Builder.new do
      use Rack::Timeout, settings

      map "/" do
        run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']] }
      end

      map "/sleep" do
        run lambda { |env| sleep }
      end
    end
  end
end
