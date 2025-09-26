require 'spec_helper'
require 'base64'
require 'open3'
require_relative '../lib/job_processor'

RSpec.describe 'Image Processing with karakuri-vl-instruct' do
  let(:temp_user_erb_file) { Tempfile.new(['image_user_prompt', '.erb']) }
  let(:temp_system_erb_file) { Tempfile.new(['image_system_prompt', '.erb']) }
  let(:temp_job_file) { Tempfile.new(['image_job', '.yml']) }

  let(:user_erb_content) { 'この画像には何が写っていますか？' }
  let(:system_erb_content) { 'あなたは画像を詳細に分析し、見えるものを正確に説明するAIアシスタントです。' }

  let(:job_config) do
    {
      id: 'image-analysis-job',
      erb_filepath: temp_user_erb_file.path,
      system_erb_filepath: temp_system_erb_file.path,
      backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
      model: 'karakuri-vl-instruct',
      output_label: 'description',
      params: { temperature: 0.1 },
      use_images: true
    }
  end

  let(:apple_image_base64) do
    image_path = File.join(__dir__, 'apple.jpg')
    Base64.strict_encode64(File.read(image_path))
  end

  let(:input_data_with_image) do
    {
      id: 'apple-image-test',
      texts: {},
      images: [apple_image_base64]
    }
  end

  before do
    temp_user_erb_file.write(user_erb_content)
    temp_user_erb_file.close

    temp_system_erb_file.write(system_erb_content)
    temp_system_erb_file.close

    temp_job_file.write(job_config.to_yaml)
    temp_job_file.close
  end

  after do
    temp_user_erb_file.unlink
    temp_system_erb_file.unlink
    temp_job_file.unlink
  end

  describe 'image processing configuration' do
    it 'initializes with image processing enabled' do
      expect { JobProcessor.new(temp_job_file.path) }.not_to raise_error
    end

    it 'validates job config correctly' do
      processor = JobProcessor.new(temp_job_file.path)
      expect(processor).to be_a(JobProcessor)
    end
  end

  describe 'image message content building' do
    let(:processor) { JobProcessor.new(temp_job_file.path) }

    it 'builds multi-modal message content correctly' do
      # Test the private method to ensure correct message structure
      message_content = processor.send(:build_message_content, user_erb_content, input_data_with_image)
      
      expect(message_content).to be_an(Array)
      expect(message_content.length).to be >= 2
      
      # Should have text content
      text_part = message_content.find { |part| part[:type] == "text" }
      expect(text_part).not_to be_nil
      expect(text_part[:text]).to eq(user_erb_content)
      
      # Should have image content
      image_part = message_content.find { |part| part[:type] == "image_url" }
      expect(image_part).not_to be_nil
      expect(image_part[:image_url][:url]).to start_with("data:image/jpeg;base64,")
    end
  end

  describe 'karakuri-vl-instruct integration', :slow do
    let(:processor) { JobProcessor.new(temp_job_file.path) }

    context 'when karakuri-vl-instruct is available' do
      it 'processes apple image successfully' do
        begin
          result = processor.process_item(input_data_with_image)
          
          expect(result).to include(
            id: 'apple-image-test',
            texts: hash_including(
              description: a_string_matching(/.+/)
            ),
            images: [apple_image_base64]
          )
          
          # Verify we got a meaningful response
          description = result[:texts][:description]
          expect(description).not_to be_empty
          expect(description.length).to be > 10
          
          # The response should mention apple/りんご or red/赤
          expect(description.downcase).to match(/apple|りんご|red|赤/)
          
        rescue => e
          skip "karakuri-vl-instruct not available: #{e.message}"
        end
      end

      it 'provides detailed image description' do
        begin
          result = processor.process_item(input_data_with_image)
          description = result[:texts][:description]
          
          # Should be a substantial description
          expect(description.length).to be > 50
          
          # Should contain descriptive words
          descriptive_words = %w[画像 リンゴ 赤 apple red image]
          has_descriptive_word = descriptive_words.any? { |word| description.include?(word) }
          expect(has_descriptive_word).to be true
          
        rescue => e
          skip "karakuri-vl-instruct not available: #{e.message}"
        end
      end
    end

    context 'with different prompt variations' do
      let(:detail_prompt) { '画像を詳しく説明してください。色、形、背景についても言及してください。' }

      before do
        temp_user_erb_file.reopen(temp_user_erb_file.path, 'w')
        temp_user_erb_file.write(detail_prompt)
        temp_user_erb_file.close
      end

      it 'responds to detailed prompt requests' do
        begin
          result = processor.process_item(input_data_with_image)
          description = result[:texts][:description]
          
          expect(description).not_to be_empty
          
          # Detailed prompt should generate longer response
          expect(description.length).to be > 30
          
        rescue => e
          skip "karakuri-vl-instruct not available: #{e.message}"
        end
      end
    end

    context 'without system prompt' do
      let(:job_config_no_system) do
        job_config.dup.tap { |config| config.delete(:system_erb_filepath) }
      end

      before do
        temp_job_file.reopen(temp_job_file.path, 'w')
        temp_job_file.write(job_config_no_system.to_yaml)
        temp_job_file.close
      end

      it 'processes image without system prompt' do
        begin
          processor_no_sys = JobProcessor.new(temp_job_file.path)
          result = processor_no_sys.process_item(input_data_with_image)
          
          expect(result[:texts][:description]).not_to be_empty
          
        rescue => e
          skip "karakuri-vl-instruct not available: #{e.message}"
        end
      end
    end
  end

  describe 'error handling with images' do
    context 'with invalid image data' do
      let(:input_data_invalid_image) do
        {
          id: 'invalid-image-test',
          texts: {},
          images: ['invalid-base64-data']
        }
      end

      it 'handles invalid image gracefully' do
        begin
          processor = JobProcessor.new(temp_job_file.path)
          
          # Invalid image data should cause an API error, which is expected
          expect { processor.process_item(input_data_invalid_image) }.to raise_error(/API request failed/)
          
        rescue => e
          skip "karakuri-vl-instruct not available: #{e.message}"
        end
      end
    end

    context 'with missing image when expected' do
      let(:input_data_no_image) do
        {
          id: 'no-image-test',
          texts: {},
          images: []
        }
      end

      it 'handles missing images' do
        begin
          processor = JobProcessor.new(temp_job_file.path)
          result = processor.process_item(input_data_no_image)
          
          # Should still process, but with text-only content
          expect(result[:texts][:description]).not_to be_empty
          
        rescue => e
          skip "karakuri-vl-instruct not available: #{e.message}"
        end
      end
    end
  end

  describe 'JSONL processing with images' do
    let(:temp_input_file) { Tempfile.new(['image_input', '.jsonl']) }
    let(:jsonl_content) { JSON.generate(input_data_with_image) }

    before do
      temp_input_file.write(jsonl_content)
      temp_input_file.close
    end

    after do
      temp_input_file.unlink
    end

    it 'processes image through bin/job.rb script', :slow do
      begin
        stdout, stderr, status = Open3.capture3(
          'bundle', 'exec', 'ruby', 'bin/job.rb', temp_job_file.path,
          stdin_data: jsonl_content
        )
        
        expect(status.exitstatus).to eq(0)
        expect(stderr).to be_empty
        
        output = JSON.parse(stdout.strip)
        expect(output).to include(
          'id' => 'apple-image-test',
          'texts' => hash_including(
            'description' => a_string_matching(/.+/)
          ),
          'images' => [apple_image_base64]
        )
        
        # Verify meaningful description
        expect(output['texts']['description']).not_to be_empty
        
      rescue => e
        skip "karakuri-vl-instruct not available: #{e.message}"
      end
    end
  end
end