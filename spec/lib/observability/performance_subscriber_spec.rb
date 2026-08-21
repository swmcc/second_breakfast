require "rails_helper"

RSpec.describe Observability::PerformanceSubscriber do
  let(:logger) { instance_double(ActiveSupport::Logger, warn: nil) }
  let(:started) { Time.utc(2026, 8, 21, 9, 30, 0) }

  before { allow(Observability).to receive(:logger).and_return(logger) }

  def request_event(seconds)
    ActiveSupport::Notifications::Event.new(
      "process_action.action_controller",
      started,
      started + seconds,
      "id",
      {
        controller: "RecipesController", action: "index", method: "GET",
        path: "/recipes?query=cake", status: 200, db_runtime: 5.0, view_runtime: 3.0
      }
    )
  end

  def sql_event(seconds, name: "Recipe Load", sql: "SELECT * FROM recipes WHERE id = $1", cached: false)
    ActiveSupport::Notifications::Event.new(
      "sql.active_record", started, started + seconds, "id",
      { name: name, sql: sql, cached: cached }
    )
  end

  describe "slow requests" do
    it "warns above the threshold" do
      described_class.log_slow_request(request_event(2.0))

      expect(logger).to have_received(:warn).with(
        hash_including(
          event: "slow_request",
          duration: 2000.0,
          controller_action: "RecipesController#index",
          path: "/recipes"
        )
      )
    end

    it "stays quiet below the threshold" do
      described_class.log_slow_request(request_event(0.01))

      expect(logger).not_to have_received(:warn)
    end

    it "honours SLOW_REQUEST_MS" do
      allow(Observability).to receive(:slow_request_threshold_ms).and_return(5.0)

      described_class.log_slow_request(request_event(0.01))

      expect(logger).to have_received(:warn).with(hash_including(event: "slow_request", threshold: 5.0))
    end
  end

  describe "slow SQL" do
    it "warns above the threshold without logging bind values" do
      described_class.log_slow_query(sql_event(1.0))

      expect(logger).to have_received(:warn).with(
        hash_including(event: "slow_sql", duration: 1000.0, sql: "SELECT * FROM recipes WHERE id = $1")
      )
    end

    it "stays quiet below the threshold" do
      described_class.log_slow_query(sql_event(0.001))

      expect(logger).not_to have_received(:warn)
    end

    it "ignores schema, transaction and cached queries" do
      described_class.log_slow_query(sql_event(1.0, name: "SCHEMA"))
      described_class.log_slow_query(sql_event(1.0, name: "TRANSACTION"))
      described_class.log_slow_query(sql_event(1.0, cached: true))

      expect(logger).not_to have_received(:warn)
    end
  end
end
