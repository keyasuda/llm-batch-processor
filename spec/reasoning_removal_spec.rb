require 'spec_helper'
require_relative '../lib/job_processor'

RSpec.describe 'Reasoning Removal Feature' do
  let(:temp_erb_file) { Tempfile.new(['reasoning_prompt', '.erb']) }
  let(:temp_job_file) { Tempfile.new(['reasoning_job', '.yml']) }
  
  let(:job_config) do
    {
      id: 'reasoning-test-job',
      erb_filepath: temp_erb_file.path,
      backend_endpoint: 'https://api.example.com',
      model: 'test-model',
      output_label: 'response',
      use_images: false
    }
  end

  let(:erb_content) { 'Test prompt: <%= texts[:input] %>' }
  
  before do
    temp_erb_file.write(erb_content)
    temp_erb_file.close
    
    temp_job_file.write(job_config.to_yaml)
    temp_job_file.close
  end

  after do
    temp_erb_file.unlink
    temp_job_file.unlink
  end

  describe '#clean_content' do
    let(:processor) { JobProcessor.new(temp_job_file.path) }

    context 'with reasoning tags' do
      it 'removes single line reasoning' do
        content = '<think>This is my reasoning</think>This is the actual response.'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('This is the actual response.')
      end

      it 'removes multi-line reasoning' do
        content = <<~TEXT
          <think>
          Let me think about this step by step:
          1. First consideration
          2. Second consideration
          </think>
          This is the final answer.
        TEXT
        
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('This is the final answer.')
      end

      it 'removes multiple reasoning blocks' do
        content = <<~TEXT
          <think>First reasoning block</think>
          Some text in between.
          <think>Second reasoning block</think>
          Final answer here.
        TEXT
        
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq("Some text in between.\n\nFinal answer here.")
      end

      it 'handles reasoning at the end' do
        content = 'Here is my answer. <think>Some reasoning at the end</think>'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('Here is my answer.')
      end

      it 'handles reasoning at the beginning' do
        content = '<think>Initial reasoning</think> Here is the answer.'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('Here is the answer.')
      end

      it 'handles nested-like content but removes outer tags only' do
        content = '<think>I think <something> is important</think>Final answer.'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('Final answer.')
      end
    end

    context 'without reasoning tags' do
      it 'returns content unchanged' do
        content = 'This is a normal response without reasoning tags.'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq(content)
      end

      it 'handles empty content' do
        content = ''
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('')
      end

      it 'handles whitespace-only content' do
        content = '   '
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('')
      end
    end

    context 'with malformed tags' do
      it 'handles unclosed think tags' do
        content = '<think>Reasoning without closing tag. This is the answer.'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq(content) # Should not remove anything if malformed
      end

      it 'handles closing tags without opening' do
        content = 'Answer here. </think>'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq(content) # Should not remove anything if malformed
      end

      it 'handles similar but different tags' do
        content = '<thinking>This is not a think tag</thinking>Answer here.'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq(content) # Should not remove different tags
      end
    end

    context 'with Japanese content' do
      it 'removes reasoning in Japanese' do
        content = '<think>これは推論プロセスです</think>これが最終的な回答です。'
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('これが最終的な回答です。')
      end

      it 'handles mixed language reasoning' do
        content = <<~TEXT
          <think>
          Let me think about this in Japanese:
          これは日本語での推論です
          </think>
          日本語での回答です。
        TEXT
        
        cleaned = processor.send(:clean_content, content)
        expect(cleaned).to eq('日本語での回答です。')
      end
    end
  end

  describe 'integration with mocked API responses' do
    let(:processor) { JobProcessor.new(temp_job_file.path) }
    let(:input_data) do
      {
        id: 'reasoning-test',
        texts: { input: 'test input' },
        images: []
      }
    end

    before do
      # Mock the OpenAI client
      mock_client = double('OpenAI::Client')
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
    end

    context 'when API returns content with reasoning' do
      it 'removes reasoning from the final output' do
        mock_client = double('OpenAI::Client')
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        
        api_response_with_reasoning = {
          'choices' => [
            {
              'message' => {
                'content' => '<think>Let me analyze this carefully</think>This is my final answer.'
              }
            }
          ]
        }
        
        allow(mock_client).to receive(:chat).and_return(api_response_with_reasoning)
        
        result = processor.process_item(input_data)
        
        expect(result[:texts][:response]).to eq('This is my final answer.')
      end

      it 'handles complex reasoning with newlines' do
        mock_client = double('OpenAI::Client')
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        
        api_response_complex = {
          'choices' => [
            {
              'message' => {
                'content' => <<~RESPONSE
                  <think>
                  Step 1: Analyze the question
                  Step 2: Consider multiple perspectives
                  Step 3: Formulate the answer
                  </think>
                  Based on my analysis, the answer is 42.
                RESPONSE
              }
            }
          ]
        }
        
        allow(mock_client).to receive(:chat).and_return(api_response_complex)
        
        result = processor.process_item(input_data)
        
        expect(result[:texts][:response]).to eq('Based on my analysis, the answer is 42.')
      end
    end

    context 'when API returns content without reasoning' do
      it 'leaves normal content unchanged' do
        mock_client = double('OpenAI::Client')
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        
        api_response_normal = {
          'choices' => [
            {
              'message' => {
                'content' => 'This is a normal response without any reasoning tags.'
              }
            }
          ]
        }
        
        allow(mock_client).to receive(:chat).and_return(api_response_normal)
        
        result = processor.process_item(input_data)
        
        expect(result[:texts][:response]).to eq('This is a normal response without any reasoning tags.')
      end
    end
  end
end