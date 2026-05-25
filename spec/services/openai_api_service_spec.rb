require "ostruct"
require "rails_helper"

RSpec.describe OpenaiApiService, type: :model do
  describe "#generate_manuscript_content" do
    before do
      ENV["OPENAI_API_KEY"] = "test-key"
    end

    after do
      ENV.delete("OPENAI_API_KEY")
    end

    it "initializes the OpenAI client with the API key from environment" do
      client = instance_double(OpenAI::Client)
      allow(OpenAI::Client).to receive(:new).with(api_key: "test-key").and_return(client)
      allow(client).to receive_message_chain(:chat, :completions, :create).and_return(double(deep_to_h: { "choices" => [] }))

      service = OpenaiApiService.new
      expect(service.instance_variable_get(:@client)).to eq(client)
    end

    it "raises an error when OPENAI_API_KEY is missing" do
      ENV.delete("OPENAI_API_KEY")
      service = OpenaiApiService.new(client: instance_double(OpenAI::Client))

      expect do
        service.generate_manuscript_content(OpenStruct.new)
      end.to raise_error(OpenaiApiService::ApiKeyMissingError, "OPENAI_API_KEY is not configured")
    end

    it "parses generated_body and image_prompt from the OpenAI response" do
      response_hash = {
        "choices" => [
          {
            "message" => {
              "content" => '{"generated_body":"テスト本文","image_prompt":"テストプロンプト"}'
            }
          }
        ]
      }

      response = double('response', deep_to_h: response_hash)

      client = instance_double(OpenAI::Client)
      allow(client).to receive_message_chain(:chat, :completions, :create).and_return(response)
      allow(OpenAI::Client).to receive(:new).with(api_key: "test-key").and_return(client)

      manuscript = OpenStruct.new(
        title: "テスト",
        service_name: "サービス",
        service_summary: "概要",
        target: "ターゲット",
        purpose: "目的",
        strengths: "強み",
        urgency_reason: "緊急",
        contact_methods: "問い合わせ",
        phone_number: "000-0000-0000",
        fax_number: "000-0000-0000",
        email: "example@example.com",
        website_url: "https://example.com",
        reception_hours: "9:00-18:00",
        address: "住所",
        credibility: "信頼",
        opt_out_notice: "配信停止"
      )

      service = OpenaiApiService.new
      result = service.generate_manuscript_content(manuscript)

      expect(result["generated_body"]).to eq("テスト本文")
      expect(result["image_prompt"]).to eq("テストプロンプト")
    end
  end
end
