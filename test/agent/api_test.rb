require_relative "test_helper"

class ApiTest < Minitest::Test
  class FakeScanner
    def ping(_ip)
      true
    end

    def check_ports(_ip)
      []
    end
  end

  class FakeWol
    def wake(_mac)
      nil
    end
  end

  def test_a_non_string_target_is_422
    assert_equal 422, call_action("ping", 7)
  end

  def test_a_scan_with_a_target_is_422
    assert_equal 422, call_action("scan", "pc")
  end

  def test_a_scan_without_a_target_is_200
    assert_equal 200, call_action("scan", nil)
  end

  def test_a_valid_action_is_200
    assert_equal 200, call_action("ping", "pc")
  end

  private

  def call_action(action, target)
    body = JSON.generate("action" => action, "target" => target)
    request = { path: "/api/action", method: "POST", body: body }
    api.call(request).first
  rescue Agent::HttpError => error
    error.code
  end

  def api
    chat = Agent::Chat.new({ config: Agent::Config.new, registry: AgentTest.device_registry,
                             scanner: FakeScanner.new, snapshot: AgentTest::StubSnapshot.new,
                             wol: FakeWol.new, llm: AgentTest::FakeLlm.new })
    Agent::Api.new({ config: Agent::Config.new, snapshot: AgentTest::StubSnapshot.new,
                     monitor: AgentTest::StubMonitor.new, chat: chat })
  end
end
