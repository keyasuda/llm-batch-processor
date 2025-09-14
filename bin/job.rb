#! /usr/bin/env ruby

require_relative '../lib/job_processor'

# Main execution
if ARGV.length != 1
  STDERR.puts "Usage: #{$0} <job_definition.yml>"
  exit 1
end

job_definition_path = ARGV[0]

unless File.exist?(job_definition_path)
  STDERR.puts "Job definition file not found: #{job_definition_path}"
  exit 1
end

begin
  processor = JobProcessor.new(job_definition_path)
  processor.process
rescue => e
  STDERR.puts "Error: #{e.message}"
  exit 1
end