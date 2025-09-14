require 'spec_helper'
require 'open3'

RSpec.describe 'bin/job.rb script' do
  let(:temp_erb_file) { Tempfile.new(['script_prompt', '.erb']) }
  let(:temp_job_file) { Tempfile.new(['script_job', '.yml']) }
  let(:temp_input_file) { Tempfile.new(['script_input', '.jsonl']) }
  
  let(:job_config) do
    {
      id: 'script-test-job',
      erb_filepath: temp_erb_file.path,
      backend_endpoint: 'https://api.example.com',
      model: 'gpt-3.5-turbo',
      output_label: 'response',
      use_images: false
    }
  end

  let(:erb_content) { 'Test prompt: <%= texts[:input] %>' }
  let(:input_jsonl) { '{"id": "test1", "texts": {"input": "test message"}}' }
  
  before do
    temp_erb_file.write(erb_content)
    temp_erb_file.close
    
    temp_job_file.write(job_config.to_yaml)
    temp_job_file.close
    
    temp_input_file.write(input_jsonl)
    temp_input_file.close
  end

  after do
    temp_erb_file.unlink
    temp_job_file.unlink
    temp_input_file.unlink
  end

  describe 'command line interface' do
    it 'shows usage when no arguments provided' do
      stdout, stderr, status = Open3.capture3('bundle', 'exec', 'ruby', 'bin/job.rb')
      
      expect(status.exitstatus).to eq(1)
      expect(stderr).to include('Usage:')
    end

    it 'shows error for non-existent job file' do
      stdout, stderr, status = Open3.capture3('bundle', 'exec', 'ruby', 'bin/job.rb', '/non/existent/file.yml')
      
      expect(status.exitstatus).to eq(1)
      expect(stderr).to include('Job definition file not found')
    end

    context 'with mocked API responses' do
      before do
        # Mock successful API response - need to match the exact request
        stub_request(:post, "https://api.example.com/v1/chat/completions")
          .to_return(
            status: 200,
            body: {
              choices: [
                {
                  message: {
                    content: "Mocked response from API"
                  }
                }
              ]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'processes JSONL input successfully' do
        stdout, stderr, status = Open3.capture3(
          'bundle', 'exec', 'ruby', 'bin/job.rb', temp_job_file.path,
          stdin_data: input_jsonl
        )
        
        expect(status.exitstatus).to eq(0)
        expect(stderr).to be_empty
        
        output = JSON.parse(stdout.strip)
        expect(output).to include(
          'id' => 'test1',
          'texts' => hash_including(
            'input' => 'test message',
            'response' => 'Mocked response from API'
          )
        )
      end

      it 'handles multiple JSONL lines' do
        multi_input = [
          '{"id": "test1", "texts": {"input": "first message"}}',
          '{"id": "test2", "texts": {"input": "second message"}}'
        ].join("\n")
        
        stdout, stderr, status = Open3.capture3(
          'bundle', 'exec', 'ruby', 'bin/job.rb', temp_job_file.path,
          stdin_data: multi_input
        )
        
        expect(status.exitstatus).to eq(0)
        
        lines = stdout.strip.split("\n")
        expect(lines.length).to eq(2)
        
        result1 = JSON.parse(lines[0])
        result2 = JSON.parse(lines[1])
        
        expect(result1['id']).to eq('test1')
        expect(result2['id']).to eq('test2')
      end
    end

    context 'with API errors' do
      before do
        stub_request(:post, "https://api.example.com/v1/chat/completions")
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'handles API errors gracefully' do
        stdout, stderr, status = Open3.capture3(
          'bundle', 'exec', 'ruby', 'bin/job.rb', temp_job_file.path,
          stdin_data: input_jsonl
        )
        
        expect(status.exitstatus).to eq(0) # Script continues processing
        expect(stderr).to include('Error processing item')
        expect(stdout).to be_empty # No successful output
      end
    end

    context 'with malformed JSON input' do
      let(:bad_jsonl) { '{"id": "test1", "texts": invalid json}' }

      it 'handles JSON parsing errors gracefully' do
        stdout, stderr, status = Open3.capture3(
          'bundle', 'exec', 'ruby', 'bin/job.rb', temp_job_file.path,
          stdin_data: bad_jsonl
        )
        
        expect(status.exitstatus).to eq(0) # Script continues
        expect(stderr).to include('Error parsing JSON line')
        expect(stdout).to be_empty
      end
    end
  end
end