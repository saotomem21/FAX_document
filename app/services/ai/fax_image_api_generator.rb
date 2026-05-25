require "openai"
require "net/http"
require "fileutils"
require "base64"

module Ai
  class FaxImageApiGenerator
    class ApiKeyMissingError < StandardError; end
    class ImageGenerationError < StandardError; end

    DALL_E_MODEL = "gpt-image-2"
    DEFAULT_SIZE = "1024x1024"
    MAX_PROMPT_LENGTH = 8000

    # FAX DM design system instruction — loaded from prompt file
    PROMPT_FILE_PATH = Rails.root.join("app/services/prompt/fax_document_prompt.md")

    def self.system_instruction
      @system_instruction ||= File.read(PROMPT_FILE_PATH).strip
    end

    def initialize(manuscript, client: nil)
      @manuscript = manuscript
      @client = client || OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])
    end

    # Returns [relative_path, image_url] on success, or nil if API key is missing
    def generate!(version_number:)
      raise ApiKeyMissingError, "OPENAI_API_KEY is not configured" if ENV["OPENAI_API_KEY"].blank?
      raise ImageGenerationError, "image_prompt is blank" if @manuscript.image_prompt.blank?

      Rails.logger.info "[FaxImageApiGenerator] Calling DALL-E API with prompt length: #{@manuscript.image_prompt.length} chars"

      full_prompt = build_full_prompt
      response = @client.images.generate(
        model: DALL_E_MODEL,
        prompt: full_prompt,
        size: DEFAULT_SIZE,
        n: 1
      )

      # Normalize response to a Hash
      raw = normalize_response(response)

      # gpt-image-2 may return b64_json instead of url
      b64_data = extract_b64_json(raw)
      image_url = extract_image_url(raw)

      if b64_data
        Rails.logger.info "[FaxImageApiGenerator] Received base64 image data (#{b64_data.length} chars)"
      elsif image_url
        Rails.logger.info "[FaxImageApiGenerator] DALL-E returned image URL: #{image_url}"
      else
        raise ImageGenerationError, "DALL-E response did not contain image data: #{raw.inspect}"
      end

      # Save image locally
      image_dir = storage_root.join("generated_images")
      FileUtils.mkdir_p(image_dir)
      filename = "manuscript_#{@manuscript.id}_v#{version_number}.png"
      local_path = image_dir.join(filename)

      if b64_data
        File.write(local_path, Base64.decode64(b64_data), mode: "wb")
      else
        download_image(image_url, local_path)
      end

      relative_path = local_path.relative_path_from(Rails.root).to_s
      Rails.logger.info "[FaxImageApiGenerator] Image saved to: #{relative_path}"

      [relative_path, image_url || "b64"]
    rescue ApiKeyMissingError => e
      Rails.logger.info "[FaxImageApiGenerator] #{e.message} — falling back to SVG"
      nil
    rescue => e
      Rails.logger.error "[FaxImageApiGenerator] Image generation failed: #{e.message}"
      nil
    end

    private

    def normalize_response(response)
      return nil if response.nil?

      if response.respond_to?(:deep_to_h)
        begin
          response.deep_to_h
        rescue StandardError
          nil
        end
      elsif response.is_a?(Hash)
        response
      else
        nil
      end
    end

    def extract_image_url(raw)
      return nil unless raw.is_a?(Hash)

      raw.dig("data", 0, "url") ||
        raw.dig(:data, 0, :url) ||
        raw["data"]&.first&.dig("url") ||
        raw[:data]&.first&.dig(:url)
    end

    def extract_b64_json(raw)
      return nil unless raw.is_a?(Hash)

      raw.dig("data", 0, "b64_json") ||
        raw.dig(:data, 0, :b64_json) ||
        raw["data"]&.first&.dig("b64_json") ||
        raw[:data]&.first&.dig(:b64_json)
    end

    def download_image(url, local_path)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise ImageGenerationError, "Failed to download image: HTTP #{response.code}"
      end

      File.write(local_path, response.body, mode: "wb")
    end

    def build_full_prompt
      image_prompt = @manuscript.image_prompt.to_s.strip
      instruction = self.class.system_instruction
      combined = "#{instruction}\n\n#{image_prompt}"

      if combined.length > MAX_PROMPT_LENGTH
        # Truncate image_prompt portion to fit within limit
        max_image_chars = MAX_PROMPT_LENGTH - instruction.length - 2
        Rails.logger.warn "[FaxImageApiGenerator] Prompt too long (#{combined.length} chars), truncating image_prompt to #{max_image_chars} chars"
        "#{instruction}\n\n#{image_prompt.first(max_image_chars)}"
      else
        combined
      end
    end

    def storage_root
      Rails.env.test? ? Rails.root.join("tmp/storage") : Rails.root.join("storage")
    end
  end
end
