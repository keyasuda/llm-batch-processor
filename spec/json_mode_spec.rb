require 'spec_helper'
require 'fileutils'
require_relative '../lib/job_processor'

RSpec.describe 'JSON Mode Support' do
  let(:temp_dir) { Dir.mktmpdir('json_mode_test') }
  let(:schemas_dir) { File.join(temp_dir, 'schemas') }
  let(:templates_dir) { File.join(temp_dir, 'templates') }

  before do
    FileUtils.mkdir_p([schemas_dir, templates_dir])
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe 'configuration validation' do
    let(:job_yaml_path) { File.join(temp_dir, 'job.yml') }
    let(:user_erb_path) { File.join(templates_dir, 'user.erb') }
    let(:schema_path) { File.join(schemas_dir, 'test_schema.yml') }

    let(:user_erb_content) { 'Extract data from: <%= texts[:input] %>' }
    let(:schema_content) do
      {
        type: 'object',
        properties: {
          name: { type: 'string' },
          value: { type: 'number' }
        },
        required: ['name']
      }
    end

    before do
      File.write(user_erb_path, user_erb_content)
      File.write(schema_path, schema_content.to_yaml)
    end

    context 'with simple JSON mode' do
      let(:job_config_simple) do
        {
          id: 'simple-json-test',
          erb_filepath: 'templates/user.erb',
          backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
          model: 'test-model',
          json_mode: true,
          output_label: 'response',
          use_images: false
        }
      end

      it 'initializes successfully with json_mode enabled' do
        File.write(job_yaml_path, job_config_simple.to_yaml)
        expect { JobProcessor.new(job_yaml_path) }.not_to raise_error
      end

      it 'adds response_format for simple JSON mode' do
        File.write(job_yaml_path, job_config_simple.to_yaml)
        processor = JobProcessor.new(job_yaml_path)
        
        parameters = { model: 'test-model', messages: [] }
        processor.send(:add_json_response_format!, parameters)
        
        expect(parameters[:response_format]).to eq({
          type: 'json_object'
        })
      end
    end

    context 'with schema-constrained JSON mode' do
      let(:job_config_schema) do
        {
          id: 'schema-json-test',
          erb_filepath: 'templates/user.erb',
          json_schema_filepath: 'schemas/test_schema.yml',
          backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      it 'initializes successfully with json_schema_filepath' do
        File.write(job_yaml_path, job_config_schema.to_yaml)
        expect { JobProcessor.new(job_yaml_path) }.not_to raise_error
      end

      it 'adds response_format with schema for schema mode' do
        File.write(job_yaml_path, job_config_schema.to_yaml)
        processor = JobProcessor.new(job_yaml_path)
        
        parameters = { model: 'test-model', messages: [] }
        processor.send(:add_json_response_format!, parameters)
        
        expect(parameters[:response_format]).to eq({
          type: 'json_object',
          schema: schema_content
        })
      end

      it 'resolves schema file path correctly' do
        File.write(job_yaml_path, job_config_schema.to_yaml)
        processor = JobProcessor.new(job_yaml_path)
        
        resolved_path = processor.send(:resolve_erb_path, 'schemas/test_schema.yml')
        expect(resolved_path).to eq(schema_path)
      end
    end

    context 'error handling' do
      let(:job_config_missing_schema) do
        {
          id: 'missing-schema-test',
          erb_filepath: 'templates/user.erb',
          json_schema_filepath: 'schemas/nonexistent.yml',
          backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      it 'raises error for missing schema file' do
        File.write(job_yaml_path, job_config_missing_schema.to_yaml)
        expect { JobProcessor.new(job_yaml_path) }.to raise_error(/JSON schema file not found/)
      end

      it 'includes resolved path in error message' do
        File.write(job_yaml_path, job_config_missing_schema.to_yaml)
        begin
          JobProcessor.new(job_yaml_path)
        rescue => e
          expected_path = File.join(schemas_dir, 'nonexistent.yml')
          expect(e.message).to include(expected_path)
        end
      end
    end

    context 'without JSON mode' do
      let(:job_config_normal) do
        {
          id: 'normal-test',
          erb_filepath: 'templates/user.erb',
          backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      it 'does not add response_format when JSON mode is disabled' do
        File.write(job_yaml_path, job_config_normal.to_yaml)
        processor = JobProcessor.new(job_yaml_path)
        
        parameters = { model: 'test-model', messages: [] }
        processor.send(:add_json_response_format!, parameters)
        
        expect(parameters).not_to have_key(:response_format)
      end
    end

    context 'with inline JSON schema' do
      let(:inline_schema) do
        {
          type: 'object',
          properties: {
            name: { type: 'string' },
            age: { type: 'integer', minimum: 0 },
            skills: {
              type: 'array',
              items: { type: 'string' }
            }
          },
          required: ['name']
        }
      end

      let(:job_config_inline) do
        {
          id: 'inline-schema-test',
          erb_filepath: 'templates/user.erb',
          json_schema: inline_schema,
          backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      it 'initializes successfully with inline json_schema' do
        File.write(job_yaml_path, job_config_inline.to_yaml)
        expect { JobProcessor.new(job_yaml_path) }.not_to raise_error
      end

      it 'adds response_format with inline schema' do
        File.write(job_yaml_path, job_config_inline.to_yaml)
        processor = JobProcessor.new(job_yaml_path)
        
        parameters = { model: 'test-model', messages: [] }
        processor.send(:add_json_response_format!, parameters)
        
        expect(parameters[:response_format]).to eq({
          type: 'json_object',
          schema: inline_schema
        })
      end
    end

    context 'with both json_mode and json_schema_filepath' do
      let(:job_config_both) do
        {
          id: 'both-json-test',
          erb_filepath: 'templates/user.erb',
          json_mode: true,
          json_schema_filepath: 'schemas/test_schema.yml',
          backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      it 'prioritizes schema file over simple json_mode' do
        File.write(job_yaml_path, job_config_both.to_yaml)
        processor = JobProcessor.new(job_yaml_path)
        
        parameters = { model: 'test-model', messages: [] }
        processor.send(:add_json_response_format!, parameters)
        
        expect(parameters[:response_format]).to eq({
          type: 'json_object',
          schema: schema_content
        })
      end
    end

    context 'with priority order: inline > file > simple' do
      let(:inline_schema) do
        {
          type: 'object',
          properties: {
            inline_field: { type: 'string' }
          }
        }
      end

      let(:job_config_all_three) do
        {
          id: 'all-three-test',
          erb_filepath: 'templates/user.erb',
          json_mode: true,
          json_schema_filepath: 'schemas/test_schema.yml',
          json_schema: inline_schema,
          backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      it 'prioritizes inline schema over all others' do
        File.write(job_yaml_path, job_config_all_three.to_yaml)
        processor = JobProcessor.new(job_yaml_path)
        
        parameters = { model: 'test-model', messages: [] }
        processor.send(:add_json_response_format!, parameters)
        
        expect(parameters[:response_format]).to eq({
          type: 'json_object',
          schema: inline_schema
        })
      end
    end
  end

  describe 'integration with mocked API responses' do
    let(:job_yaml_path) { File.join(temp_dir, 'job.yml') }
    let(:user_erb_path) { File.join(templates_dir, 'user.erb') }
    let(:schema_path) { File.join(schemas_dir, 'person.yml') }

    let(:user_erb_content) { 'Extract person info from: <%= texts[:input] %>' }
    let(:person_schema) do
      {
        type: 'object',
        properties: {
          name: { type: 'string' },
          age: { type: 'integer', minimum: 0 }
        },
        required: ['name']
      }
    end

    let(:job_config) do
      {
        id: 'integration-test',
        erb_filepath: 'templates/user.erb',
        json_schema_filepath: 'schemas/person.yml',
        backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
        model: 'test-model',
        output_label: 'person_data',
        use_images: false
      }
    end

    let(:input_data) do
      {
        id: 'test1',
        texts: { input: 'John is 30 years old' },
        images: []
      }
    end

    before do
      File.write(user_erb_path, user_erb_content)
      File.write(schema_path, person_schema.to_yaml)
      File.write(job_yaml_path, job_config.to_yaml)

      # Mock the OpenAI client
      mock_client = double('OpenAI::Client')
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      
      json_response = '{"name": "John", "age": 30}'
      mock_api_response = {
        'choices' => [
          {
            'message' => {
              'content' => json_response
            }
          }
        ]
      }
      
      allow(mock_client).to receive(:chat).and_return(mock_api_response)
    end

    it 'processes item with JSON schema successfully' do
      processor = JobProcessor.new(job_yaml_path)
      result = processor.process_item(input_data)
      
      expect(result).to include(
        id: 'test1',
        texts: hash_including(
          input: 'John is 30 years old',
          person_data: '{"name": "John", "age": 30}'
        )
      )
    end

    it 'passes correct parameters to API call' do
      # Create a fresh mock client for this test
      mock_client = double('OpenAI::Client')
      
      expected_params = hash_including(
        response_format: {
          type: 'json_object',
          schema: person_schema
        }
      )
      
      expect(mock_client).to receive(:chat).with(parameters: expected_params).and_return({
        'choices' => [{ 'message' => { 'content' => '{"name": "John", "age": 30}' } }]
      })
      
      # Mock the client creation for this specific test
      allow(OpenAI::Client).to receive(:new).and_return(mock_client)
      
      processor = JobProcessor.new(job_yaml_path)
      processor.process_item(input_data)
    end
  end

  describe 'complex schema handling' do
    let(:job_yaml_path) { File.join(temp_dir, 'job.yml') }
    let(:user_erb_path) { File.join(templates_dir, 'user.erb') }
    let(:complex_schema_path) { File.join(schemas_dir, 'complex.yml') }

    let(:complex_schema) do
      {
        type: 'object',
        properties: {
          summary: {
            type: 'object',
            properties: {
              title: { type: 'string', maxLength: 100 },
              content: { type: 'string', minLength: 10 }
            },
            required: ['title', 'content']
          },
          tags: {
            type: 'array',
            items: { type: 'string' },
            minItems: 1,
            maxItems: 5
          },
          metadata: {
            type: 'object',
            properties: {
              created_at: { type: 'string', format: 'date-time' },
              confidence: { type: 'number', minimum: 0.0, maximum: 1.0 }
            }
          }
        },
        required: ['summary', 'tags']
      }
    end

    before do
      File.write(user_erb_path, 'Analyze: <%= texts[:input] %>')
      File.write(complex_schema_path, complex_schema.to_yaml)
    end

    it 'handles complex nested schema correctly' do
      job_config = {
        id: 'complex-schema-test',
        erb_filepath: 'templates/user.erb',
        json_schema_filepath: 'schemas/complex.yml',
        backend_endpoint: ENV['LLM_API_ENDPOINT'] || 'http://localhost:8080',
        model: 'test-model',
        output_label: 'analysis',
        use_images: false
      }

      File.write(job_yaml_path, job_config.to_yaml)
      processor = JobProcessor.new(job_yaml_path)
      
      parameters = { model: 'test-model', messages: [] }
      processor.send(:add_json_response_format!, parameters)
      
      expect(parameters[:response_format][:schema]).to eq(complex_schema)
    end
  end
end