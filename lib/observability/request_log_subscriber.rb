# frozen_string_literal: true

module Observability
  # One structured summary line per request, in the spirit of lograge but
  # without the dependency (lograge is in maintenance mode and has no Rails 8
  # release of its own).
  #
  # When this is attached in JSON mode we also detach Rails' own
  # `ActionController::LogSubscriber` so a request produces one line instead of
  # the usual "Processing by.../Completed 200 OK" pair.
  module RequestLogSubscriber
    EVENT = "process_action.action_controller"

    class << self
      def attach!
        @subscriber ||= ActiveSupport::Notifications.subscribe(EVENT) do |*args|
          log(ActiveSupport::Notifications::Event.new(*args))
        end
      end

      def detach!
        return if @subscriber.nil?

        ActiveSupport::Notifications.unsubscribe(@subscriber)
        @subscriber = nil
      end

      # Stop Rails logging the same request itself.
      def silence_default_controller_logging!
        ActionController::LogSubscriber.detach_from :action_controller
      rescue StandardError => e
        Rails.logger.warn("could not detach ActionController::LogSubscriber: #{e.class}")
      end

      def log(event)
        Observability.logger.info(payload_for(event))
      rescue StandardError => e
        # Instrumentation must never break a request.
        Observability.report_instrumentation_error(e)
      end

      def payload_for(event)
        payload = event.payload

        {
          event: "request",
          method: payload[:method],
          path: scrub_path(payload[:path]),
          controller: payload[:controller],
          action: payload[:action],
          controller_action: "#{payload[:controller]}##{payload[:action]}",
          format: payload[:format]&.to_s,
          status: status_for(payload),
          duration: round(event.duration),
          view_duration: round(payload[:view_runtime]),
          db_duration: round(payload[:db_runtime]),
          exception: payload[:exception]&.first
        }
      end

      def status_for(payload)
        return payload[:status] if payload[:status]
        return unless payload[:exception]

        ActionDispatch::ExceptionWrapper.status_code_for_exception(payload[:exception].first)
      end

      # Query strings can carry user input; keep the path only.
      def scrub_path(path)
        path&.split("?")&.first
      end

      def round(value)
        value&.to_f&.round(2)
      end
    end
  end
end
