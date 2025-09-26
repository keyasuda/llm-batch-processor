require 'spec_helper'
require 'open3'
require_relative '../lib/job_processor'

RSpec.describe 'Reasoning Removal Integration' do
  let(:temp_erb_file) { Tempfile.new(['reasoning_integration_prompt', '.erb']) }
  let(:temp_system_erb_file) { Tempfile.new(['reasoning_integration_system', '.erb']) }
  let(:temp_job_file) { Tempfile.new(['reasoning_integration_job', '.yml']) }

  let(:job_config) do
    {
      id: 'reasoning-integration-test',
      erb_filepath: temp_erb_file.path,
      system_erb_filepath: temp_system_erb_file.path,
      backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
      model: 'qwen3-0.6b',
      output_label: 'response',
      params: { temperature: 0.1 },
      use_images: false
    }
  end

  let(:erb_content) { '簡単な算数問題: 2 + 3 = ?' }
  let(:system_erb_content) { 'あなたは数学の先生です。<think>タグを使って推論過程を示してから、最終的な答えを提供してください。' }

  before do
    temp_erb_file.write(erb_content)
    temp_erb_file.close

    temp_system_erb_file.write(system_erb_content)
    temp_system_erb_file.close

    temp_job_file.write(job_config.to_yaml)
    temp_job_file.close
  end

  after do
    temp_erb_file.unlink
    temp_system_erb_file.unlink
    temp_job_file.unlink
  end

  describe 'reasoning removal with qwen3-0.6b', :slow do
    let(:processor) { JobProcessor.new(temp_job_file.path) }
    let(:input_data) do
      {
        id: 'reasoning-integration-test',
        texts: {},
        images: []
      }
    end

    it 'removes reasoning tags from actual LLM response' do
      begin
        result = processor.process_item(input_data)
        
        response_content = result[:texts][:response]
        
        # Verify we got a response
        expect(response_content).not_to be_empty
        
        # Most importantly: verify no <think> tags remain in the output
        expect(response_content).not_to include('<think>')
        expect(response_content).not_to include('</think>')
        
        # The response should contain the answer but not the reasoning process
        expect(response_content).to match(/5|五/)
        
        puts "Cleaned response: #{response_content.inspect}"
        
      rescue => e
        skip "qwen3-0.6b not available: #{e.message}"
      end
    end

    it 'handles responses without reasoning tags normally' do
      begin
        # Use a different prompt that's less likely to generate reasoning
        temp_erb_file.reopen(temp_erb_file.path, 'w')
        temp_erb_file.write('こんにちは')
        temp_erb_file.close

        # Use system prompt that doesn't encourage reasoning tags
        temp_system_erb_file.reopen(temp_system_erb_file.path, 'w')
        temp_system_erb_file.write('あなたは親切なアシスタントです。簡潔に回答してください。')
        temp_system_erb_file.close

        result = processor.process_item(input_data)
        
        response_content = result[:texts][:response]
        
        # Should still get a valid response
        expect(response_content).not_to be_empty
        expect(response_content).not_to include('<think>')
        expect(response_content).not_to include('</think>')
        
      rescue => e
        skip "qwen3-0.6b not available: #{e.message}"
      end
    end
  end

  describe 'command line integration with reasoning removal', :slow do
    let(:input_jsonl) { '{"id": "cmd-reasoning-test", "texts": {}}' }

    it 'removes reasoning from command line output' do
      begin
        stdout, stderr, status = Open3.capture3(
          'bundle', 'exec', 'ruby', 'bin/job.rb', temp_job_file.path,
          stdin_data: input_jsonl
        )
        
        expect(status.exitstatus).to eq(0)
        expect(stderr).to be_empty
        
        output = JSON.parse(stdout.strip)
        response_content = output['texts']['response']
        
        # Verify reasoning tags are removed
        expect(response_content).not_to include('<think>')
        expect(response_content).not_to include('</think>')
        
        # Should still contain meaningful content
        expect(response_content).not_to be_empty
        
      rescue JSON::ParserError => e
        fail "Invalid JSON output: #{stdout}"
      rescue => e
        skip "qwen3-0.6b not available: #{e.message}"
      end
    end
  end
end