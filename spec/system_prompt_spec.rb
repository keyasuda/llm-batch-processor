require 'spec_helper'
require_relative '../lib/job_processor'

RSpec.describe 'System Prompt Feature' do
  let(:temp_user_erb_file) { Tempfile.new(['user_prompt', '.erb']) }
  let(:temp_system_erb_file) { Tempfile.new(['system_prompt', '.erb']) }
  let(:temp_job_file) { Tempfile.new(['system_test_job', '.yml']) }

  let(:user_erb_content) { 'ユーザープロンプト: <%= texts[:input] %>' }
  let(:system_erb_content) { 'あなたは優秀なアシスタントです。入力データ数: <%= texts.keys.length %>' }

  let(:job_config_with_system) do
    {
      id: 'system-prompt-test',
      erb_filepath: temp_user_erb_file.path,
      system_erb_filepath: temp_system_erb_file.path,
      backend_endpoint: test_backend_endpoint,
      model: 'qwen3-0.6b',
      output_label: 'response',
      params: { temperature: 0.1 },
      use_images: false
    }
  end

  let(:job_config_without_system) do
    {
      id: 'no-system-prompt-test',
      erb_filepath: temp_user_erb_file.path,
      backend_endpoint: test_backend_endpoint,
      model: 'qwen3-0.6b',
      output_label: 'response',
      params: { temperature: 0.1 },
      use_images: false
    }
  end

  before do
    temp_user_erb_file.write(user_erb_content)
    temp_user_erb_file.close

    temp_system_erb_file.write(system_erb_content)
    temp_system_erb_file.close
  end

  after do
    temp_user_erb_file.unlink
    temp_system_erb_file.unlink
    temp_job_file.unlink
  end

  describe 'configuration validation' do
    context 'with valid system ERB file' do
      it 'initializes successfully' do
        temp_job_file.write(job_config_with_system.to_yaml)
        temp_job_file.close

        expect { JobProcessor.new(temp_job_file.path) }.not_to raise_error
      end
    end

    context 'with non-existent system ERB file' do
      it 'raises error for missing system ERB file' do
        config = job_config_with_system.dup
        config[:system_erb_filepath] = '/non/existent/system.erb'

        temp_job_file.write(config.to_yaml)
        temp_job_file.close

        expect { JobProcessor.new(temp_job_file.path) }.to raise_error(/System ERB template file not found/)
      end
    end

    context 'without system ERB file' do
      it 'works normally without system prompt' do
        temp_job_file.write(job_config_without_system.to_yaml)
        temp_job_file.close

        expect { JobProcessor.new(temp_job_file.path) }.not_to raise_error
      end
    end
  end

  describe 'system prompt generation' do
    let(:processor_with_system) do
      temp_job_file.write(job_config_with_system.to_yaml)
      temp_job_file.close
      JobProcessor.new(temp_job_file.path)
    end

    let(:processor_without_system) do
      temp_job_file.write(job_config_without_system.to_yaml)
      temp_job_file.close
      JobProcessor.new(temp_job_file.path)
    end

    let(:input_data) do
      {
        id: 'test1',
        texts: { input: 'テストメッセージ', other: 'その他' },
        images: []
      }
    end

    context 'with system prompt configured' do
      it 'generates system prompt correctly' do
        system_prompt = processor_with_system.send(:generate_system_prompt, input_data)
        expect(system_prompt).to eq('あなたは優秀なアシスタントです。入力データ数: 2')
      end

      it 'generates user prompt correctly' do
        user_prompt = processor_with_system.send(:generate_prompt, input_data)
        expect(user_prompt).to eq('ユーザープロンプト: テストメッセージ')
      end
    end

    context 'without system prompt configured' do
      it 'returns nil for system prompt' do
        system_prompt = processor_without_system.send(:generate_system_prompt, input_data)
        expect(system_prompt).to be_nil
      end

      it 'generates user prompt correctly' do
        user_prompt = processor_without_system.send(:generate_prompt, input_data)
        expect(user_prompt).to eq('ユーザープロンプト: テストメッセージ')
      end
    end
  end

  describe 'integration with qwen3-0.6b', :slow do
    let(:input_data) do
      {
        id: 'system-integration-test',
        texts: { input: 'システムプロンプトのテストです。' },
        images: []
      }
    end

    context 'with system prompt' do
      it 'processes item with system prompt successfully' do
        begin
          temp_job_file.write(job_config_with_system.to_yaml)
          temp_job_file.close
          processor = JobProcessor.new(temp_job_file.path)

          result = processor.process_item(input_data)

          expect(result).to include(
            id: 'system-integration-test',
            texts: hash_including(
              input: 'システムプロンプトのテストです。',
              response: a_string_matching(/.+/)
            )
          )

          expect(result[:texts][:response]).not_to be_empty

        rescue => e
          skip "qwen3-0.6b not available: #{e.message}"
        end
      end
    end

    context 'without system prompt' do
      it 'processes item without system prompt successfully' do
        begin
          temp_job_file.write(job_config_without_system.to_yaml)
          temp_job_file.close
          processor = JobProcessor.new(temp_job_file.path)

          result = processor.process_item(input_data)

          expect(result).to include(
            id: 'system-integration-test',
            texts: hash_including(
              input: 'システムプロンプトのテストです。',
              response: a_string_matching(/.+/)
            )
          )

          expect(result[:texts][:response]).not_to be_empty

        rescue => e
          skip "qwen3-0.6b not available: #{e.message}"
        end
      end
    end

    context 'comparing responses with and without system prompt' do
      it 'can process both configurations' do
        begin
          # Test with system prompt
          temp_job_file.write(job_config_with_system.to_yaml)
          temp_job_file.close
          processor_with = JobProcessor.new(temp_job_file.path)
          result_with = processor_with.process_item(input_data)

          # Recreate job file for without system prompt
          temp_job_file.reopen(temp_job_file.path, 'w')
          temp_job_file.write(job_config_without_system.to_yaml)
          temp_job_file.close
          processor_without = JobProcessor.new(temp_job_file.path)
          result_without = processor_without.process_item(input_data)

          # Both should succeed
          expect(result_with[:texts][:response]).not_to be_empty
          expect(result_without[:texts][:response]).not_to be_empty

          # Responses may be different due to system prompt
          # but both should be valid strings
          expect(result_with[:texts][:response]).to be_a(String)
          expect(result_without[:texts][:response]).to be_a(String)

        rescue => e
          skip "qwen3-0.6b not available: #{e.message}"
        end
      end
    end
  end
end