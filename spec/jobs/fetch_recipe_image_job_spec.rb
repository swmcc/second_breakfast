# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchRecipeImageJob do
  subject(:perform_job) { described_class.perform_now(recipe.id) }

  let(:recipe) { create(:recipe, title: "Toast") }
  let(:search_response) do
    instance_double(Net::HTTPSuccess,
                    body: { photos: [ { src: { large: "https://images.pexels.com/photo.jpg" } } ] }.to_json)
  end

  def image_response(content_type:, body: "image data")
    instance_double(Net::HTTPSuccess, body: body).tap do |response|
      allow(response).to receive(:[]).with("Content-Type").and_return(content_type)
    end
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("PEXELS_API_KEY").and_return("test-key")
    allow(Rails.logger).to receive(:warn)
  end

  context "with an allowed image response" do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_with_timeout)
        .and_return(search_response, image_response(content_type: "image/png"))
    end

    it "attaches the downloaded image" do
      perform_job

      expect(recipe.reload.image).to be_attached
      expect(recipe.image.blob.content_type).to eq("image/png")
    end

    it "searches Pexels with the API key and a recipe-suffixed query" do
      expect_any_instance_of(described_class).to receive(:fetch_with_timeout)
        .with("https://api.pexels.com/v1/search?query=Toast+recipe&per_page=5",
              headers: { "Authorization" => "test-key" })
        .and_return(search_response)
      expect_any_instance_of(described_class).to receive(:fetch_with_timeout)
        .with("https://images.pexels.com/photo.jpg")
        .and_return(image_response(content_type: "image/jpeg"))

      perform_job
    end
  end

  context "with a non-image response" do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_with_timeout)
        .and_return(search_response, image_response(content_type: "text/html"))
    end

    it "does not attach the response and logs why" do
      expect { perform_job }.not_to raise_error

      expect(recipe.reload.image).not_to be_attached
      expect(Rails.logger).to have_received(:warn).with(/unsupported image Content-Type: text\/html/)
    end
  end

  context "with an unsupported image response" do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_with_timeout)
        .and_return(search_response, image_response(content_type: "image/svg+xml"))
    end

    it "does not attach the response" do
      perform_job

      expect(recipe.reload.image).not_to be_attached
    end
  end

  context "with an oversized image response" do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_with_timeout)
        .and_return(search_response, image_response(content_type: "image/jpeg", body: "x" * 2_000_001))
    end

    it "does not attach the response and logs why" do
      perform_job

      expect(recipe.reload.image).not_to be_attached
      expect(Rails.logger).to have_received(:warn).with(/oversized image/)
    end
  end

  context "when PEXELS_API_KEY is not set" do
    before do
      allow(ENV).to receive(:[]).with("PEXELS_API_KEY").and_return(nil)
    end

    it "makes no HTTP calls, attaches nothing, and logs a warning" do
      expect_any_instance_of(described_class).not_to receive(:fetch_with_timeout)

      perform_job

      expect(recipe.reload.image).not_to be_attached
      expect(Rails.logger).to have_received(:warn).with(/PEXELS_API_KEY is not set/)
    end
  end

  context "when the Pexels search returns no usable response" do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_with_timeout).and_return(nil)
    end

    it "does not attach anything and logs a warning" do
      perform_job

      expect(recipe.reload.image).not_to be_attached
      expect(Rails.logger).to have_received(:warn).with(/no usable response from Pexels/)
    end
  end

  context "when Pexels finds no photos" do
    let(:search_response) { instance_double(Net::HTTPSuccess, body: { photos: [] }.to_json) }

    before do
      allow_any_instance_of(described_class).to receive(:fetch_with_timeout).and_return(search_response)
    end

    it "does not attach anything and logs a warning" do
      perform_job

      expect(recipe.reload.image).not_to be_attached
      expect(Rails.logger).to have_received(:warn).with(/no Pexels photos/)
    end
  end

  context "when the recipe already has an image" do
    before do
      recipe.image.attach(io: StringIO.new("existing"), filename: "existing.jpg", content_type: "image/jpeg")
    end

    it "makes no HTTP calls" do
      expect_any_instance_of(described_class).not_to receive(:fetch_with_timeout)

      perform_job
    end
  end

  context "when the recipe no longer exists" do
    it "does nothing" do
      expect { described_class.perform_now(0) }.not_to raise_error
    end
  end
end
