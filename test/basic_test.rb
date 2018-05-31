require "test_helper"

class BasicTest < RackTimeoutTest
  def initialize(*args)
    self.settings = { service_timeout: 1 }
    super(*args)
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
