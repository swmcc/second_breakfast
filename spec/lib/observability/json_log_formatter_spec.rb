require "rails_helper"

RSpec.describe Observability::JsonLogFormatter do
  subject(:formatter) { described_class.new }

  let(:timestamp) { Time.utc(2026, 8, 21, 9, 30, 15, 250_000) }

  def parse(line)
    expect(line).to end_with("\n")
    JSON.parse(line)
  end

  around do |example|
    Observability::Current.set(request_id: "req-abc-123", user_id: 42) { example.run }
  end

  it "emits a single line of parseable JSON for a string message" do
    line = formatter.call("INFO", timestamp, nil, "hello world")

    expect(line.count("\n")).to eq(1)
    expect(parse(line)).to include(
      "timestamp" => "2026-08-21T09:30:15.250Z",
      "level" => "INFO",
      "message" => "hello world",
      "request_id" => "req-abc-123",
      "user_id" => 42
    )
  end

  it "merges a Hash message into the envelope" do
    payload = parse(
      formatter.call("INFO", timestamp, nil, {
        event: "request",
        method: "GET",
        path: "/recipes/1",
        status: 200,
        duration: 12.34,
        controller: "RecipesController",
        action: "show",
        controller_action: "RecipesController#show"
      })
    )

    expect(payload).to include(
      "timestamp" => "2026-08-21T09:30:15.250Z",
      "level" => "INFO",
      "request_id" => "req-abc-123",
      "event" => "request",
      "method" => "GET",
      "path" => "/recipes/1",
      "status" => 200,
      "duration" => 12.34,
      "controller_action" => "RecipesController#show"
    )
  end

  it "carries every key the log stream is expected to be queryable on" do
    payload = parse(
      formatter.call("INFO", timestamp, nil, Observability::RequestLogSubscriber.payload_for(request_event))
    )

    expect(payload.keys).to include(
      "timestamp", "level", "request_id",
      "method", "path", "status", "duration",
      "controller", "action", "controller_action"
    )
  end

  it "omits blank values rather than emitting nulls" do
    payload = parse(formatter.call("WARN", timestamp, nil, "no progname here"))

    expect(payload).not_to have_key("progname")
  end

  it "renders an exception message and a trimmed backtrace" do
    error = RuntimeError.new("boom")
    error.set_backtrace(Array.new(50) { |i| "line #{i}" })

    payload = parse(formatter.call("ERROR", timestamp, nil, error))

    expect(payload["message"]).to eq("RuntimeError: boom")
    expect(payload["exception"]).to eq("RuntimeError")
    expect(payload["backtrace"].length).to eq(20)
  end

  it "drops a blank message instead of logging whitespace" do
    payload = parse(formatter.call("INFO", timestamp, nil, "  \n "))

    expect(payload).not_to have_key("message")
    expect(payload).to include("level" => "INFO")
  end

  it "never raises, even for a message that cannot be serialised" do
    unserialisable = Object.new
    def unserialisable.inspect = "<opaque>"

    expect(parse(formatter.call("INFO", timestamp, nil, unserialisable))).to include("message" => "<opaque>")
  end

  def request_event
    ActiveSupport::Notifications::Event.new(
      "process_action.action_controller",
      timestamp,
      timestamp + 0.015,
      "id",
      {
        controller: "RecipesController",
        action: "show",
        method: "GET",
        path: "/recipes/1?utm_source=x",
        status: 200,
        format: :html,
        view_runtime: 8.0,
        db_runtime: 2.0
      }
    )
  end
end
