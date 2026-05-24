require "test_helper"
require "ostruct"

class OpenaiApiServiceTest < ActiveSupport::TestCase
  def with_openai_client_stub(client)
    original_new = OpenAI::Client.method(:new)
    OpenAI::Client.singleton_class.define_method(:new) { |*_args| client }
    yield
  ensure
    OpenAI::Client.singleton_class.define_method(:new, original_new)
  end

  test "initializes OpenAI client with api_key from environment" do
    ENV["OPENAI_API_KEY"] = "test-key"

    client = Object.new
    def client.chat
      nil
    end

    with_openai_client_stub(client) do
      service = OpenaiApiService.new
      assert service.instance_variable_get(:@client).present?
    end
  ensure
    ENV.delete("OPENAI_API_KEY")
  end

  test "raises when OPENAI_API_KEY is missing" do
    ENV.delete("OPENAI_API_KEY")

    service = OpenaiApiService.new(client: Object.new)
    error = assert_raises(OpenaiApiService::ApiKeyMissingError) do
      service.generate_manuscript_content(OpenStruct.new)
    end

    assert_equal "OPENAI_API_KEY is not configured", error.message
  end

  test "parses generated body and image prompt from OpenAI response" do
    ENV["OPENAI_API_KEY"] = "test-key"
    response = {
      "choices" => [
        {
          "message" => {
            "content" => '{"generated_body":"テスト本文","image_prompt":"テストプロンプト"}'
          }
        }
      ]
    }

    chat = Object.new
    def chat.completions(parameters:)
      @response
    end

    client = Object.new
    def client.chat
      @chat
    end

    client.instance_variable_set(:@chat, chat)
    chat.instance_variable_set(:@response, response)

    with_openai_client_stub(client) do
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

      assert_equal "テスト本文", result["generated_body"]
      assert_equal "テストプロンプト", result["image_prompt"]
    end
  ensure
    ENV.delete("OPENAI_API_KEY")
  end
end
