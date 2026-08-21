require "rails_helper"

RSpec.describe Observability::MetricsSubscriber do
  let(:started) { Time.utc(2026, 8, 21, 9, 30, 0) }

  def event(controller:, action:, status: 200, params: {}, exception: nil)
    ActiveSupport::Notifications::Event.new(
      "process_action.action_controller",
      started,
      started + 0.01,
      "id",
      { controller: controller, action: action, status: status, params: params, exception: exception }
    )
  end

  before { allow(Observability::Metrics).to receive(:emit) }

  it "counts a recipe creation" do
    described_class.record(event(controller: "RecipesController", action: "create", status: 302))

    expect(Observability::Metrics).to have_received(:emit).with("recipe.created", source: "web")
  end

  it "counts a recipe view with its id" do
    described_class.record(event(controller: "RecipesController", action: "show", params: { "id" => "12" }))

    expect(Observability::Metrics).to have_received(:emit).with("recipe.viewed", source: "web", recipe_id: "12")
  end

  it "counts an API recipe view separately from a web one" do
    described_class.record(
      event(controller: "Api::V1::RecipesController", action: "show", params: { "id" => "12" })
    )

    expect(Observability::Metrics).to have_received(:emit).with("recipe.viewed", source: "api", recipe_id: "12")
  end

  it "counts a search along with the query" do
    described_class.record(
      event(controller: "RecipesController", action: "search", params: { "query" => " Pancakes " })
    )

    expect(Observability::Metrics)
      .to have_received(:emit).with("search.performed", source: "web", query: "pancakes", query_length: 8)
  end

  it "ignores actions that are not tracked" do
    described_class.record(event(controller: "RecipesController", action: "index"))

    expect(Observability::Metrics).not_to have_received(:emit)
  end

  it "ignores a failed create" do
    described_class.record(event(controller: "RecipesController", action: "create", status: 422))

    expect(Observability::Metrics).not_to have_received(:emit)
  end

  it "ignores an action that raised" do
    described_class.record(
      event(controller: "RecipesController", action: "show", status: nil, exception: [ "RuntimeError", "boom" ])
    )

    expect(Observability::Metrics).not_to have_received(:emit)
  end
end
