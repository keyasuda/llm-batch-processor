require 'bundler/setup'
require 'openai'
require 'yaml'
require 'json'
require 'erb'

class JobProcessor
  def initialize(job_definition_path)
    @job_definition_path = job_definition_path
    @job_config = YAML.load_file(job_definition_path, symbolize_names: true)
    validate_config!
    setup_openai_client
  end

  def process
    STDIN.each_line do |line|
      line = line.strip
      next if line.empty?
      
      begin
        input_data = JSON.parse(line, symbolize_names: true)
        result = process_item(input_data)
        puts JSON.generate(result)
      rescue JSON::ParserError => e
        STDERR.puts "Error parsing JSON line: #{e.message}"
        next
      rescue => e
        STDERR.puts "Error processing item: #{e.message}"
        next
      end
    end
  end

  def process_item(input_data)
    # Generate prompts using ERB templates
    user_prompt = generate_prompt(input_data)
    system_prompt = generate_system_prompt(input_data)
    
    # Call LLM API
    llm_response = call_llm_api(user_prompt, input_data, system_prompt)
    
    # Build result
    result = {
      id: input_data[:id],
      texts: input_data[:texts] || {},
      images: input_data[:images] || []
    }
    
    # Add LLM output to the specified label
    result[:texts][@job_config[:output_label].to_sym] = llm_response
    
    result
  end

  private

  def setup_openai_client
    # Remove trailing /v1 from endpoint if present, as ruby-openai gem adds it automatically
    uri_base = @job_config[:backend_endpoint].sub(/\/v1\/?$/, '')
    
    @client = OpenAI::Client.new(
      access_token: ENV['OPENAI_API_KEY'] || 'dummy-key',
      uri_base: uri_base,
      request_timeout: 240
    )
  end

  def validate_config!
    required_keys = [:id, :erb_filepath, :backend_endpoint, :model, :output_label]
    missing_keys = required_keys - @job_config.keys
    
    unless missing_keys.empty?
      raise "Missing required configuration keys: #{missing_keys.join(', ')}"
    end

    # Check ERB file path (resolve relative to YAML file)
    erb_path = resolve_erb_path(@job_config[:erb_filepath])
    unless File.exist?(erb_path)
      raise "ERB template file not found: #{erb_path}"
    end

    # Validate system prompt ERB file if specified
    if @job_config[:system_erb_filepath]
      system_erb_path = resolve_erb_path(@job_config[:system_erb_filepath])
      unless File.exist?(system_erb_path)
        raise "System ERB template file not found: #{system_erb_path}"
      end
    end
  end

  def resolve_erb_path(erb_filepath)
    # If path is absolute, use as-is
    return erb_filepath if File.absolute_path?(erb_filepath)
    
    # If path is relative, resolve relative to the job definition YAML file
    job_dir = File.dirname(@job_definition_path)
    resolved_path = File.join(job_dir, erb_filepath)
    
    # Normalize the path to handle parent directory references (..)
    File.expand_path(resolved_path)
  end

  def generate_prompt(input_data)
    erb_path = resolve_erb_path(@job_config[:erb_filepath])
    erb_content = File.read(erb_path)
    erb = ERB.new(erb_content)
    
    # Make input_data available in ERB context
    texts = input_data[:texts] || {}
    images = input_data[:images] || []
    
    erb.result(binding)
  end

  def generate_system_prompt(input_data)
    return nil unless @job_config[:system_erb_filepath]
    
    system_erb_path = resolve_erb_path(@job_config[:system_erb_filepath])
    erb_content = File.read(system_erb_path)
    erb = ERB.new(erb_content)
    
    # Make input_data available in ERB context
    texts = input_data[:texts] || {}
    images = input_data[:images] || []
    
    erb.result(binding)
  end

  def call_llm_api(user_prompt, input_data, system_prompt = nil)
    # Build messages array
    messages = []
    
    # Add system message if system prompt is provided
    if system_prompt && !system_prompt.strip.empty?
      messages << {
        role: "system",
        content: system_prompt
      }
    end
    
    # Add user message
    messages << {
      role: "user",
      content: build_message_content(user_prompt, input_data)
    }
    
    # Build request parameters
    parameters = {
      model: @job_config[:model],
      messages: messages
    }
    
    # Add optional parameters if specified
    if @job_config[:params]
      parameters.merge!(@job_config[:params])
    end
    
    # Make API call using ruby-openai gem
    response = @client.chat(parameters: parameters)
    
    # Extract content from response
    raw_content = response.dig("choices", 0, "message", "content") || ""
    
    # Remove reasoning tags if present
    clean_content(raw_content)
  rescue => e
    raise "API request failed: #{e.message}"
  end

  def clean_content(content)
    # Remove <think>...</think> tags and their content
    content.gsub(/<think>.*?<\/think>/m, '').strip
  end

  def build_message_content(prompt, input_data)
    if @job_config[:use_images] && input_data[:images] && !input_data[:images].empty?
      # Multi-modal content with images
      content = [
        {
          type: "text",
          text: prompt
        }
      ]
      
      input_data[:images].each do |image_base64|
        content << {
          type: "image_url",
          image_url: {
            url: "data:image/jpeg;base64,#{image_base64}"
          }
        }
      end
      
      content
    else
      # Text-only content
      prompt
    end
  end
end