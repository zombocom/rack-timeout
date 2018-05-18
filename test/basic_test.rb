require "test/unit"
require "rack/test"
require "rack-timeout"

class BasicTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::Timeout, service_timeout: 1

      map "/" do
        run lambda { |env| [200, {'Content-Type' => 'text/plain'}, ['OK']] }
      end

      map "/sleep" do
        run lambda { |env| sleep }
      end
    end
  end

  def test_ok
    get "/"
    assert last_response.ok?
  end

  def test_timeout
    assert_raises(Rack::Timeout::RequestTimeoutError) do
      get "/sleep"
    end
  end
end
