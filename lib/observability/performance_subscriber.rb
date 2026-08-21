# frozen_string_literal: true

module Observability
  # Poor-man's APM: warn-level structured lines for requests and SQL queries
  # that cross a configurable threshold. This is deliberately a log-stream
  # concern rather than a SaaS agent - see the PR/issue notes on New Relic and
  # Scout, both of which need a paid account and a licence key.
  #
  # Thresholds: SLOW_REQUEST_MS (default 1000), SLOW_QUERY_MS (default 500).
  module PerformanceSubscriber
    REQUEST_EVENT = "process_action.action_controller"
    SQL_EVENT     = "sql.active_record"

    # Framework-internal queries that are noise rather than signal.
    IGNORED_SQL_NAMES = [ "SCHEMA", "TRANSACTION", "CACHE" ].freeze

    class << self
      def attach!
        @request_subscriber ||= ActiveSupport::Notifications.subscribe(REQUEST_EVENT) do |*args|
          log_slow_request(ActiveSupport::Notifications::Event.new(*args))
        end

        @sql_subscriber ||= ActiveSupport::Notifications.subscribe(SQL_EVENT) do |*args|
          log_slow_query(ActiveSupport::Notifications::Event.new(*args))
        end
      end

      def detach!
        [ @request_subscriber, @sql_subscriber ].compact.each do |subscriber|
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end
        @request_subscriber = nil
        @sql_subscriber = nil
      end

      def log_slow_request(event)
        return if event.duration < Observability.slow_request_threshold_ms

        payload = event.payload
        Observability.logger.warn({
          event: "slow_request",
          threshold: Observability.slow_request_threshold_ms,
          duration: event.duration.round(2),
          db_duration: payload[:db_runtime]&.to_f&.round(2),
          view_duration: payload[:view_runtime]&.to_f&.round(2),
          method: payload[:method],
          path: payload[:path]&.split("?")&.first,
          controller_action: "#{payload[:controller]}##{payload[:action]}"
        })
      rescue StandardError => e
        Observability.report_instrumentation_error(e)
      end

      def log_slow_query(event)
        payload = event.payload
        return if IGNORED_SQL_NAMES.include?(payload[:name])
        return if payload[:cached]
        return if event.duration < Observability.slow_query_threshold_ms

        Observability.logger.warn({
          event: "slow_sql",
          threshold: Observability.slow_query_threshold_ms,
          duration: event.duration.round(2),
          name: payload[:name],
          # The statement only - bind values are never logged, they can hold PII.
          sql: payload[:sql].to_s.squish.truncate(1_000)
        })
      rescue StandardError => e
        Observability.report_instrumentation_error(e)
      end
    end
  end
end
