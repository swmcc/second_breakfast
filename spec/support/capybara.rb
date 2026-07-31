# frozen_string_literal: true

require "capybara/rspec"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [ 1200, 800 ],
    headless: true,
    process_timeout: 30,
    timeout: 30,
    browser_options: {
      "no-sandbox" => nil,
      "disable-gpu" => nil,
      "disable-dev-shm-usage" => nil
    }
  )
end

# Speed up tests
Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :cuprite
  end
end
