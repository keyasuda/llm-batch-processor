# LLM Batch Processor - Project Context

## Project Overview

The LLM Batch Processor is a Ruby-based tool that processes jobs using Large Language Models (LLMs) through OpenAI API-compatible endpoints. The system allows users to define LLM jobs using YAML configuration files combined with ERB templates, processing input data in JSONL format from standard input and producing structured output to standard output.

### Key Features
- **ERB Templates**: Flexible user and system prompt definition using ERB templating
- **System Prompts**: Support for system-level prompts defined in separate ERB files
- **Relative Path Resolution**: ERB files can be referenced using paths relative to the YAML configuration
- **JSON Mode**: Support for structured data extraction with schema-constrained JSON output
- **JSONL Processing**: Processes input data line-by-line in JSONL format
- **OpenAI API Compatibility**: Works with any OpenAI API-compatible backend
- **Reasoning Tag Removal**: Automatically removes `<think>...</think>` tags from LLM responses
- **Image Processing**: Multi-modal support for image and text processing
- **Robust Error Handling**: Comprehensive error handling and logging

## Architecture

### Core Components
1. **bin/job.rb** - Main executable script that accepts a job definition file path as an argument
2. **lib/job_processor.rb** - Main class implementing the job processing logic
3. **YAML Configuration Files** - Define job parameters, endpoints, and processing options
4. **ERB Template Files** - Define dynamic prompts using Ruby templating

### File Structure
```
llm-batch-processor/
├── bin/
│   └── job.rb                    # Main entry point
├── lib/
│   └── job_processor.rb         # Core processing logic
├── docs/
│   └── example/                 # Example configurations and templates
├── spec/                        # Test suite
└── Gemfile                      # Dependencies
```

## Building and Running

### Setup
```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec
```

### Usage
```bash
# Basic usage
bundle exec ruby bin/job.rb path/to/job_definition.yml < input.jsonl

# Example with provided sample
bundle exec ruby bin/job.rb docs/example/job_with_system.yml < docs/example/input_sample.jsonl
```

### Configuration Format

The YAML job definition file supports the following parameters:

### Execution Patterns

The system is designed to be used in Unix-like pipelines. A common pattern is:
1. **Generator**: Script to create JSONL input (e.g., from DB or filesystem)
2. **Processor**: `bin/job.rb`
3. **Filter**: `jq` to parse and extract specific results

Agents should prefer this composable approach over creating monolithic scripts. When processing LLM output with `jq`, remember to key into the output field (e.g., `texts.result`, where `result` corresponds to the `:output_label` in the job YAML) and often use `fromjson` if the model returns a JSON string.


```yaml
---
:id: job-identifier
:erb_filepath: path/to/user_prompt.erb
:system_erb_filepath: path/to/system_prompt.erb    # Optional
:backend_endpoint: https://api.example.com         # OpenAI API-compatible endpoint
:model: model-name                                 # Model identifier
:output_label: output-field-name                   # Field name for LLM response
:params:                                           # Optional model parameters
  :temperature: 0.3
  :max_tokens: 200
:use_images: false                                 # Enable image processing
:json_mode: true                                   # Enable simple JSON mode
:json_schema:                                      # Inline JSON schema
  type: object
  properties:
    name:
      type: string
:json_schema_filepath: path/to/schema.yml          # External JSON schema file
```

### ERB Template Context
In ERB templates, the following variables are available:
- `texts` - Hash containing text data from input
- `images` - Array containing image data from input
- Any other variables passed from the input data

Example user prompt template:
```erb
以下のテキストを要約してください：

<%= texts[:content] %>
```

## Development Conventions

### Dependencies
- Ruby 3.3+
- ruby-openai gem (~> 8.3.0)
- Standard Ruby libraries: YAML, JSON, ERB

### Testing
- RSpec for unit and integration tests
- Mocking used for external API calls
- Test coverage for core functionality including ERB processing and error handling

### Error Handling
- Comprehensive validation of configuration files
- Graceful handling of missing files and invalid JSON
- Detailed error messages for debugging

### JSON Schema Support
The system supports three levels of JSON mode:
1. **Simple JSON Mode**: `:json_mode: true` for basic JSON output
2. **Inline Schema**: `:json_schema:` for schema defined directly in YAML
3. **External Schema**: `:json_schema_filepath:` for schema in separate YAML file

Priority order: Inline Schema > External Schema > Simple JSON Mode

### Multi-modal Processing
When `:use_images: true`, the system processes both text and base64-encoded images, sending them as multi-modal content to the LLM.

## Security Considerations
- API keys are read from environment variable `OPENAI_API_KEY` or defaults to a dummy key
- File path validation to prevent directory traversal attacks
- Input sanitization and validation for all configuration parameters

## Testing
Run the test suite using:
```bash
bundle exec rspec
```

The project includes tests for:
- Configuration validation
- ERB template processing
- API client setup
- Error handling scenarios
- Path resolution for relative file references