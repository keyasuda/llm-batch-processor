require 'spec_helper'
require 'fileutils'
require_relative '../lib/job_processor'

RSpec.describe 'Relative Path Support' do
  let(:temp_dir) { Dir.mktmpdir('relative_path_test') }
  let(:subdir) { File.join(temp_dir, 'templates') }

  before do
    FileUtils.mkdir_p(subdir)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe 'relative path resolution' do
    let(:job_yaml_path) { File.join(temp_dir, 'job.yml') }
    let(:user_erb_path) { File.join(subdir, 'user_prompt.erb') }
    let(:system_erb_path) { File.join(subdir, 'system_prompt.erb') }

    let(:job_config) do
      {
        id: 'relative-path-test',
        erb_filepath: 'templates/user_prompt.erb',           # Relative path
        system_erb_filepath: 'templates/system_prompt.erb',  # Relative path
        backend_endpoint: 'http://localhost:8080',
        model: 'test-model',
        output_label: 'response',
        use_images: false
      }
    end

    let(:user_erb_content) { 'User prompt: <%= texts[:input] %>' }
    let(:system_erb_content) { 'System prompt for test' }

    before do
      File.write(job_yaml_path, job_config.to_yaml)
      File.write(user_erb_path, user_erb_content)
      File.write(system_erb_path, system_erb_content)
    end

    context 'with relative paths' do
      it 'resolves user ERB file path correctly' do
        processor = JobProcessor.new(job_yaml_path)
        resolved_path = processor.send(:resolve_erb_path, 'templates/user_prompt.erb')
        expect(resolved_path).to eq(user_erb_path)
      end

      it 'resolves system ERB file path correctly' do
        processor = JobProcessor.new(job_yaml_path)
        resolved_path = processor.send(:resolve_erb_path, 'templates/system_prompt.erb')
        expect(resolved_path).to eq(system_erb_path)
      end

      it 'initializes successfully with relative paths' do
        expect { JobProcessor.new(job_yaml_path) }.not_to raise_error
      end

      it 'generates prompts using relative paths' do
        processor = JobProcessor.new(job_yaml_path)
        input_data = { id: 'test', texts: { input: 'test message' }, images: [] }

        user_prompt = processor.send(:generate_prompt, input_data)
        system_prompt = processor.send(:generate_system_prompt, input_data)

        expect(user_prompt).to eq('User prompt: test message')
        expect(system_prompt).to eq('System prompt for test')
      end
    end

    context 'with absolute paths' do
      let(:job_config_absolute) do
        {
          id: 'absolute-path-test',
          erb_filepath: user_erb_path,        # Absolute path
          system_erb_filepath: system_erb_path, # Absolute path
          backend_endpoint: 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      before do
        File.write(job_yaml_path, job_config_absolute.to_yaml)
      end

      it 'handles absolute paths correctly' do
        processor = JobProcessor.new(job_yaml_path)
        resolved_user_path = processor.send(:resolve_erb_path, user_erb_path)
        resolved_system_path = processor.send(:resolve_erb_path, system_erb_path)

        expect(resolved_user_path).to eq(user_erb_path)
        expect(resolved_system_path).to eq(system_erb_path)
      end

      it 'initializes successfully with absolute paths' do
        expect { JobProcessor.new(job_yaml_path) }.not_to raise_error
      end
    end

    context 'with mixed path types' do
      let(:job_config_mixed) do
        {
          id: 'mixed-path-test',
          erb_filepath: 'templates/user_prompt.erb',  # Relative
          system_erb_filepath: system_erb_path,        # Absolute
          backend_endpoint: 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      before do
        File.write(job_yaml_path, job_config_mixed.to_yaml)
      end

      it 'handles mixed relative and absolute paths' do
        processor = JobProcessor.new(job_yaml_path)
        resolved_user_path = processor.send(:resolve_erb_path, 'templates/user_prompt.erb')
        resolved_system_path = processor.send(:resolve_erb_path, system_erb_path)

        expect(resolved_user_path).to eq(user_erb_path)
        expect(resolved_system_path).to eq(system_erb_path)
      end

      it 'initializes and generates prompts correctly' do
        processor = JobProcessor.new(job_yaml_path)
        input_data = { id: 'test', texts: { input: 'mixed test' }, images: [] }

        user_prompt = processor.send(:generate_prompt, input_data)
        system_prompt = processor.send(:generate_system_prompt, input_data)

        expect(user_prompt).to eq('User prompt: mixed test')
        expect(system_prompt).to eq('System prompt for test')
      end
    end

    context 'with nested relative paths' do
      let(:deep_subdir) { File.join(temp_dir, 'templates', 'prompts') }
      let(:deep_user_erb_path) { File.join(deep_subdir, 'user.erb') }
      let(:deep_system_erb_path) { File.join(deep_subdir, 'system.erb') }

      let(:job_config_nested) do
        {
          id: 'nested-path-test',
          erb_filepath: 'templates/prompts/user.erb',
          system_erb_filepath: 'templates/prompts/system.erb',
          backend_endpoint: 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      before do
        FileUtils.mkdir_p(deep_subdir)
        File.write(job_yaml_path, job_config_nested.to_yaml)
        File.write(deep_user_erb_path, 'Deep user prompt: <%= texts[:input] %>')
        File.write(deep_system_erb_path, 'Deep system prompt')
      end

      it 'resolves nested relative paths correctly' do
        processor = JobProcessor.new(job_yaml_path)
        resolved_user_path = processor.send(:resolve_erb_path, 'templates/prompts/user.erb')
        resolved_system_path = processor.send(:resolve_erb_path, 'templates/prompts/system.erb')

        expect(resolved_user_path).to eq(deep_user_erb_path)
        expect(resolved_system_path).to eq(deep_system_erb_path)
      end

      it 'generates prompts from nested paths' do
        processor = JobProcessor.new(job_yaml_path)
        input_data = { id: 'test', texts: { input: 'nested test' }, images: [] }

        user_prompt = processor.send(:generate_prompt, input_data)
        system_prompt = processor.send(:generate_system_prompt, input_data)

        expect(user_prompt).to eq('Deep user prompt: nested test')
        expect(system_prompt).to eq('Deep system prompt')
      end
    end

    context 'error handling' do
      let(:job_config_missing) do
        {
          id: 'missing-file-test',
          erb_filepath: 'templates/nonexistent.erb',
          backend_endpoint: 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      before do
        File.write(job_yaml_path, job_config_missing.to_yaml)
      end

      it 'raises error for missing relative path file' do
        expect { JobProcessor.new(job_yaml_path) }.to raise_error(/ERB template file not found/)
      end

      it 'includes resolved path in error message' do
        begin
          JobProcessor.new(job_yaml_path)
        rescue => e
          expected_path = File.join(temp_dir, 'templates', 'nonexistent.erb')
          expect(e.message).to include(expected_path)
        end
      end
    end

    context 'with parent directory references' do
      let(:subdir_yaml_path) { File.join(subdir, 'job.yml') }
      let(:parent_erb_path) { File.join(temp_dir, 'parent_prompt.erb') }

      let(:job_config_parent) do
        {
          id: 'parent-ref-test',
          erb_filepath: '../parent_prompt.erb',  # Parent directory reference
          backend_endpoint: 'http://localhost:8080',
          model: 'test-model',
          output_label: 'response',
          use_images: false
        }
      end

      before do
        File.write(subdir_yaml_path, job_config_parent.to_yaml)
        File.write(parent_erb_path, 'Parent prompt: <%= texts[:input] %>')
      end

      after do
        File.delete(parent_erb_path) if File.exist?(parent_erb_path)
      end

      it 'resolves parent directory references correctly' do
        processor = JobProcessor.new(subdir_yaml_path)
        resolved_path = processor.send(:resolve_erb_path, '../parent_prompt.erb')
        expect(resolved_path).to eq(parent_erb_path)
      end

      it 'generates prompts from parent directory files' do
        processor = JobProcessor.new(subdir_yaml_path)
        input_data = { id: 'test', texts: { input: 'parent test' }, images: [] }

        user_prompt = processor.send(:generate_prompt, input_data)
        expect(user_prompt).to eq('Parent prompt: parent test')
      end
    end
  end
end