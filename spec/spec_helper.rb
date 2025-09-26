require 'bundler/setup'
require 'rspec'
require 'webmock/rspec'
require 'json'
require 'yaml'
require 'erb'
require 'tempfile'

# Disable HTTP connections except for localhost and Tailscale network (for qwen3-0.6b tests)
# Extract Tailscale host from LLM_API_ENDPOINT if set
tailscale_host = nil
if ENV['LLM_API_ENDPOINT']
  uri = URI.parse(ENV['LLM_API_ENDPOINT'])
  tailscale_host = uri.host if uri.host&.match?(/^100\./)
end

allowed_hosts = ['localhost', '127.0.0.1']
allowed_hosts << tailscale_host if tailscale_host

WebMock.disable_net_connect!(allow_localhost: true, allow: allowed_hosts)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end