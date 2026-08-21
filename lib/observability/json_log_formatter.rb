# frozen_string_literal: true

module Observability
  # Emits one JSON object per line, which is what Docker/Kamal collects from
  # STDOUT and what every log aggregator (Papertrail, LogDNA, Loki, Datadog,
  # CloudWatch...) can ingest without a parser.
  #
  # A String message becomes `{"message": "..."}`; a Hash message is merged
  # into the envelope, which is how the request, metric and slow-query
  # subscribers emit their structured fields.
  class JsonLogFormatter < ::Logger::Formatter
    # Hash keys that callers may set that should win over the envelope.
    def call(severity, timestamp, progname, message)
      payload = envelope(severity, timestamp, progname).merge(normalize(message))
      payload.compact!

      "#{::JSON.generate(payload)}\n"
    rescue StandardError => e
      # Never let logging raise. Fall back to something still parseable.
      fallback(severity, timestamp, e)
    end

    private

    def envelope(severity, timestamp, progname)
      {
        timestamp: (timestamp || Time.now).utc.iso8601(3),
        level: severity.to_s.presence || "ANY",
        progname: progname&.to_s,
        request_id: Current.request_id,
        user_id: Current.user_id
      }
    end

    def normalize(message)
      case message
      when nil
        {}
      when Hash
        message.transform_keys { |key| key.to_s.to_sym }
      when String
        stripped = message.strip
        stripped.empty? ? {} : { message: stripped }
      when Exception
        {
          message: "#{message.class}: #{message.message}",
          exception: message.class.name,
          backtrace: message.backtrace&.first(20)
        }
      else
        { message: message.inspect }
      end
    end

    def fallback(severity, timestamp, error)
      ::JSON.generate(
        timestamp: (timestamp || Time.now).utc.iso8601(3),
        level: severity.to_s,
        message: "log formatting failed: #{error.class}"
      ) + "\n"
    end
  end
end
