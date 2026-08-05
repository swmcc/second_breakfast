# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Content Security Policy", type: :system do
  it "allows the importmap and Stimulus to boot on the app itself" do
    create(:recipe)

    visit root_path

    # `javascript_importmap_tags` renders a nonced inline importmap; if the CSP
    # blocked it, no Stimulus controller would ever connect.
    expect(page).to have_css("script[type='importmap'][nonce]", visible: :hidden)
    expect(page.evaluate_script("typeof window.Stimulus")).not_to eq("undefined")
  end

  it "does not break the Swagger UI at /api-docs" do
    visit "/api-docs/index.html"

    # Swagger UI bootstraps from an inline <script>. It only renders this node if
    # that script was permitted to run, so this fails if the app CSP leaks in.
    expect(page).to have_css("#swagger-ui .swagger-ui")
  end
end
