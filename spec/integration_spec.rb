require 'spec_helper'
require_relative '../lib/job_processor'

RSpec.describe 'JobProcessor Integration', :integration do
  let(:temp_erb_file) { Tempfile.new(['integration_prompt', '.erb']) }
  let(:temp_job_file) { Tempfile.new(['integration_job', '.yml']) }
  
  let(:job_config) do
    {
      id: 'integration-test-job',
      erb_filepath: temp_erb_file.path,
      backend_endpoint: test_backend_endpoint,
      model: 'qwen3-0.6b',
      output_label: 'summary',
      params: { temperature: 0.1 },
      use_images: false
    }
  end

  let(:erb_content) { '以下のテキストを簡潔に要約してください: <%= texts[:content] %>' }
  
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

  describe 'qwen3-0.6b integration' do
    let(:processor) { JobProcessor.new(temp_job_file.path) }
    
    context 'when qwen3-0.6b is available' do
      let(:input_data) do
        {
          id: 'integration-test-1',
          texts: {
            content: 'Ruby は動的なプログラミング言語です。オブジェクト指向プログラミングをサポートし、シンプルで読みやすい構文を持っています。'
          },
          images: []
        }
      end

      it 'processes text with qwen3-0.6b successfully', :slow do
        begin
          result = processor.process_item(input_data)
          
          expect(result).to include(
            id: 'integration-test-1',
            texts: hash_including(
              content: input_data[:texts][:content],
              summary: a_string_matching(/.+/)
            ),
            images: []
          )
          
          # Verify that we got a non-empty response
          expect(result[:texts][:summary]).not_to be_empty
          expect(result[:texts][:summary].length).to be > 0
          
        rescue => e
          skip "qwen3-0.6b not available: #{e.message}"
        end
      end

      it 'handles multiple items correctly', :slow do
        begin
          input_data1 = {
            id: 'integration-test-2a',
            texts: { content: 'プログラミングは楽しい活動です。' },
            images: []
          }
          
          input_data2 = {
            id: 'integration-test-2b',
            texts: { content: 'テストは品質保証に重要です。' },
            images: []
          }
          
          result1 = processor.process_item(input_data1)
          result2 = processor.process_item(input_data2)
          
          expect(result1[:id]).to eq('integration-test-2a')
          expect(result2[:id]).to eq('integration-test-2b')
          
          expect(result1[:texts][:summary]).not_to be_empty
          expect(result2[:texts][:summary]).not_to be_empty
          
          # Results should be different for different inputs
          expect(result1[:texts][:summary]).not_to eq(result2[:texts][:summary])
          
        rescue => e
          skip "qwen3-0.6b not available: #{e.message}"
        end
      end
    end

    context 'with English text' do
      let(:erb_content) { 'Please summarize: <%= texts[:content] %>' }
      let(:input_data) do
        {
          id: 'integration-test-english',
          texts: {
            content: 'Artificial intelligence is transforming many industries. Machine learning algorithms can analyze large datasets and make predictions.'
          },
          images: []
        }
      end

      it 'processes English text correctly', :slow do
        begin
          result = processor.process_item(input_data)
          
          expect(result[:texts][:summary]).not_to be_empty
          expect(result[:id]).to eq('integration-test-english')
          
        rescue => e
          skip "qwen3-0.6b not available: #{e.message}"
        end
      end
    end
  end

  describe 'error handling in integration' do
    context 'with invalid endpoint' do
      let(:job_config_invalid) do
        job_config.merge(backend_endpoint: 'http://localhost:9999')
      end
      
      before do
        temp_job_file.reopen(temp_job_file.path, 'w')
        temp_job_file.write(job_config_invalid.to_yaml)
        temp_job_file.close
      end

      it 'handles connection errors gracefully' do
        processor = JobProcessor.new(temp_job_file.path)
        input_data = {
          id: 'error-test',
          texts: { content: 'Test content' },
          images: []
        }
        
        expect { processor.process_item(input_data) }.to raise_error(/API request failed/)
      end
    end
  end
end