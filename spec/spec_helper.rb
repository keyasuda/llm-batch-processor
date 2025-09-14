require 'bundler/setup'
require 'rspec'
require 'webmock/rspec'
require 'json'
require 'yaml'
require 'erb'
require 'tempfile'

# Disable HTTP connections except for localhost (for qwen3-0.6b tests)
WebMock.disable_net_connect!(allow_localhost: true, allow: ['localhost', '127.0.0.1'])

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end