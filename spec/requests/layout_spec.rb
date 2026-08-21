require "rails_helper"

RSpec.describe "Application layout", type: :request do
  it "renders the accessibility scaffolding on every page" do
    get root_path

    expect(response.body).to include('<html lang="en">')
    expect(response.body).to include('href="#main-content"')
    expect(response.body).to include('id="main-content"')
    expect(response.body).to include('aria-label="Main"')
    expect(response.body).to include('aria-label="Footer"')
  end

  it "does not leak partial documentation into the page" do
    create(:recipe)

    get recipes_path

    # An ERB comment ends at its first `%>`, which used to spill the rest of a
    # multi-line comment into the markup.
    expect(response.body).not_to include("Locals:")
    expect(response.body).not_to include("%>")
  end

  it "renders flash messages once, from the layout" do
    get recipes_path, params: {}, headers: {}
    follow_redirect! if response.redirect?

    expect(response.body.scan('id="flash-messages"').size).to be <= 1
  end
end
