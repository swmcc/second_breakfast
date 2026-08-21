# frozen_string_literal: true

module Observability
  # A deliberately tiny metrics surface: counters are emitted as structured
  # `metric` log lines rather than shipped to a SaaS collector, so they can be
  # counted straight out of the JSON log stream, e.g.
  #
  #   kamal app logs | jq -c 'select(.event == "metric") | .metric' | sort | uniq -c
  #
  # If a real time-series backend is adopted later, only this method needs to
  # change.
  module Metrics
    def self.emit(name, value: 1, **tags)
      Observability.logger&.info({ event: "metric", metric: name.to_s, value: value }.merge(tags))
      nil
    rescue StandardError => e
      Observability.report_instrumentation_error(e)
    end
  end
end
