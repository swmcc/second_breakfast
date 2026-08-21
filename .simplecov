# frozen_string_literal: true

# SimpleCov configuration. This file is auto-loaded by `require "simplecov"`,
# which happens at the very top of spec/spec_helper.rb (before Rails boots, so
# that code executed during boot is measured). Configuration only -- the run is
# started by `SimpleCov.start` in spec_helper.rb.
SimpleCov.configure do
  load_profile "rails"

  enable_coverage :line

  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/vendor/"
  add_filter "/bin/"
  add_filter "/test/"

  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Helpers", "app/helpers"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  add_group "Channels", "app/channels"
  add_group "Libraries", "lib"

  # Keep the denominator the same locally and on CI.
  track_files "{app,lib}/**/*.rb"

  # Enforce the floor on full-suite runs only (CI, or COVERAGE_ENFORCE=1
  # locally); a single-file run would otherwise always "fail" the threshold.
  if ENV["CI"] || ENV["COVERAGE_ENFORCE"]
    minimum_coverage line: Integer(ENV.fetch("COVERAGE_MINIMUM", "90"))
  end
end
