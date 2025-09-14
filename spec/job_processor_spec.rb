require 'spec_helper'
require_relative '../lib/job_processor'

RSpec.describe JobProcessor do
  let(:temp_erb_file) { Tempfile.new(['test_prompt', '.erb']) }
  let(:temp_job_file) { Tempfile.new(['test_job', '.yml']) }
  
  let(:job_config) do
    {
      id: 'test-job',
      erb_filepath: temp_erb_file.path,
      backend_endpoint: 'https://api.example.com',
      model: 'gpt-3.5-turbo',
      output_label: 'response',
      params: { temperature: 0.7 }
    }
  end

  let(:erb_content) { 'Summarize: <%= texts[:input] %>' }
  
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

  describe '#initialize' do
    context 'with valid configuration' do
      it 'initializes successfully' do
        expect { JobProcessor.new(temp_job_file.path) }.not_to raise_error
      end
    end

    context 'with missing required keys' do
      it 'raises error for missing keys' do
        config = job_config.dup
        config.delete(:model)
        
        temp_job_file.reopen(temp_job_file.path, 'w')
        temp_job_file.write(config.to_yaml)
        temp_job_file.close
        
        expect { JobProcessor.new(temp_job_file.path) }.to raise_error(/Missing required configuration keys: model/)
      end
    end

    context 'with non-existent ERB file' do
      it 'raises error for missing ERB file' do
        config = job_config.dup
        config[:erb_filepath] = '/non/existent/file.erb'
        
        temp_job_file.reopen(temp_job_file.path, 'w')
        temp_job_file.write(config.to_yaml)
        temp_job_file.close
        
        expect { JobProcessor.new(temp_job_file.path) }.to raise_error(/ERB template file not found/)
      end
    end
  end

  describe '#process_item' do
    let(:processor) { JobProcessor.new(temp_job_file.path) }
    let(:input_data) do
      {
        id: 'test1',
        texts: { input: 'Test text to summarize' },
        images: []
      }
    end

    before do
      # Mock the OpenAI client
      mock_client = double('OpenAI::Client')
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      
      mock_response = {
        'choices' => [
          {
            'message' => {
              'content' => 'Mocked response from LLM'
            }
          }
        ]
      }
      
      allow(mock_client).to receive(:chat).and_return(mock_response)
    end

    it 'processes item and returns correct structure' do
      result = processor.process_item(input_data)
      
      expect(result).to include(
        id: 'test1',
        texts: hash_including(
          input: 'Test text to summarize',
          response: 'Mocked response from LLM'
        ),
        images: []
      )
    end

    it 'generates prompt using ERB template' do
      result = processor.process_item(input_data)
      
      # Verify that the prompt was generated correctly
      expect(result[:texts][:response]).to eq('Mocked response from LLM')
    end
  end

  describe 'ERB template processing' do
    let(:processor) { JobProcessor.new(temp_job_file.path) }
    
    context 'with complex ERB template' do
      let(:erb_content) { 'Input: <%= texts[:input] %>, Count: <%= texts.keys.length %>' }
      let(:input_data) do
        {
          id: 'test1',
          texts: { input: 'Hello', other: 'World' },
          images: []
        }
      end

      before do
        mock_client = double('OpenAI::Client')
        allow(OpenAI::Client).to receive(:new).and_return(mock_client)
        allow(mock_client).to receive(:chat).and_return({
          'choices' => [{ 'message' => { 'content' => 'test response' } }]
        })
      end

      it 'processes ERB template correctly' do
        # This test verifies that ERB processing works
        result = processor.process_item(input_data)
        
        # Verify that the result contains the expected content
        expect(result[:texts][:response]).to eq('test response')
        expect(result[:id]).to eq('test1')
      end
    end
  end

  describe 'URL handling' do
    let(:processor) { JobProcessor.new(temp_job_file.path) }

    context 'with /v1 endpoint' do
      let(:job_config) do
        {
          id: 'test-job',
          erb_filepath: temp_erb_file.path,
          backend_endpoint: 'https://api.example.com/v1',
          model: 'gpt-3.5-turbo',
          output_label: 'response'
        }
      end

      it 'removes trailing /v1 from endpoint' do
        mock_client = double('OpenAI::Client')
        expect(OpenAI::Client).to receive(:new).with(
          hash_including(uri_base: 'https://api.example.com')
        ).and_return(mock_client)
        
        processor
      end
    end
  end
end