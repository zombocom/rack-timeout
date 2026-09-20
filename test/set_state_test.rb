require "test_helper"

class SetStateTest < Test::Unit::TestCase
  # Regression test for a crash reported when an async heartbeat/timeout
  # callback runs _set_state! after the request's info object is no longer
  # present in env (e.g. https://github.com/zombocom/rack-timeout/issues/225).
  def test_set_state_does_not_raise_when_info_is_missing
    env = {}
    assert_nothing_raised do
      Rack::Timeout._set_state! env, :active
    end
  end

  def test_set_state_still_updates_state_when_info_is_present
    info = Rack::Timeout::RequestDetails.new
    env = { Rack::Timeout::ENV_INFO_KEY => info }
    Rack::Timeout._set_state! env, :active
    assert_equal :active, info.state
  end

  def test_set_state_still_raises_for_invalid_state
    env = { Rack::Timeout::ENV_INFO_KEY => Rack::Timeout::RequestDetails.new }
    assert_raises(RuntimeError) do
      Rack::Timeout._set_state! env, :not_a_real_state
    end
  end
end
