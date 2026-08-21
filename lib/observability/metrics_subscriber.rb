# frozen_string_literal: true

module Observability
  # Turns the controller actions we care about into `metric` log lines, using
  # the `process_action.action_controller` notification that Rails already
  # publishes. Nothing is added to a controller, model or view, so removing
  # this file (and its `attach!` call) removes the feature completely - the
  # hot path is untouched either way.
  module MetricsSubscriber
    EVENT = "process_action.action_controller"

    # "Controller#action" => metric name
    TRACKED = {
      "RecipesController#create"         => "recipe.created",
      "RecipesController#show"           => "recipe.viewed",
      "RecipesController#search"         => "search.performed",
      "Api::V1::RecipesController#create" => "recipe.created",
      "Api::V1::RecipesController#show"  => "recipe.viewed",
      "Api::V1::RecipesController#search" => "search.performed"
    }.freeze

    SEARCH_METRIC = "search.performed"
    MAX_QUERY_LENGTH = 100

    class << self
      def attach!
        @subscriber ||= ActiveSupport::Notifications.subscribe(EVENT) do |*args|
          record(ActiveSupport::Notifications::Event.new(*args))
        end
      end

      def detach!
        return if @subscriber.nil?

        ActiveSupport::Notifications.unsubscribe(@subscriber)
        @subscriber = nil
      end

      def record(event)
        payload = event.payload
        metric = TRACKED["#{payload[:controller]}##{payload[:action]}"]
        return if metric.nil?
        return unless successful?(payload)

        Metrics.emit(metric, **tags_for(metric, payload))
      rescue StandardError => e
        Observability.report_instrumentation_error(e)
      end

      private

      def successful?(payload)
        status = payload[:status]
        return false if payload[:exception]
        return false if status.nil?

        status < 400
      end

      def tags_for(metric, payload)
        params = payload[:params] || {}
        tags = { source: api?(payload) ? "api" : "web" }

        if metric == SEARCH_METRIC
          query = params["query"].to_s.strip
          tags[:query] = query.downcase.truncate(MAX_QUERY_LENGTH) if query.present?
          tags[:query_length] = query.length
        elsif params["id"].present?
          tags[:recipe_id] = params["id"]
        end

        tags
      end

      def api?(payload)
        payload[:controller].to_s.start_with?("Api::")
      end
    end
  end
end
