# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchRecipeImageJob do
  subject(:perform_job) { described_class.perform_now(recipe.id) }

  let(:recipe) { create(:recipe, title: "Toast") }
  let(:token_response) { instance_double(Net::HTTPSuccess, body: 'vqd=token123&') }
  let(:search_response) do
    instance_double(Net::HTTPSuccess, body: { results: [ { width: 600, image: "https://example.com/image" } ] }.to_json)
  end

  def image_response(content_type:, body: "image data")
    instance_double(Net::HTTPSuccess, body: body).tap do |response|
      allow(response).to receive(:[]).with("Content-Type").and_return(content_type)
    end
  end

  before do
    allow_any_instance_of(described_class).to receive(:fetch_with_timeout)
      .and_return(token_response, search_response, downloaded_response)
  end

  context "with an allowed image response" do
    let(:downloaded_response) { image_response(content_type: "image/png") }

    it "attaches the downloaded image" do
      perform_job

      expect(recipe.reload.image).to be_attached
      expect(recipe.image.blob.content_type).to eq("image/png")
    end
  end

  context "with a non-image response" do
    let(:downloaded_response) { image_response(content_type: "text/html") }

    it "does not attach the response" do
      expect { perform_job }.not_to raise_error

      expect(recipe.reload.image).not_to be_attached
    end
  end

  context "with an unsupported image response" do
    let(:downloaded_response) { image_response(content_type: "image/svg+xml") }

    it "does not attach the response" do
      perform_job

      expect(recipe.reload.image).not_to be_attached
    end
  end
end
