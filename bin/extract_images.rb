#!/usr/bin/env ruby

require 'json'
require 'base64'
require 'fileutils'

def extract_images_from_jsonl(jsonl_file_path, output_directory)
  unless File.exist?(jsonl_file_path)
    STDERR.puts "JSONL file not found: #{jsonl_file_path}"
    exit 1
  end

  FileUtils.mkdir_p(output_directory) unless Dir.exist?(output_directory)

  line_number = 0
  total_images_extracted = 0

  File.foreach(jsonl_file_path) do |line|
    line_number += 1
    line = line.strip
    next if line.empty?

    begin
      json_data = JSON.parse(line)
      
      # Check if the line contains images
      if json_data.key?('images') && json_data['images'].is_a?(Array)
        json_data['images'].each_with_index do |image_base64, index|
          begin
            # Decode the base64 image data
            image_data = Base64.decode64(image_base64)
            
            # Determine the image format by checking the magic bytes
            image_format = determine_image_format(image_data)
            
            # Skip if the decoded data is not a valid image format
            if image_format.nil?
              STDERR.puts "Skipping invalid image data at line #{line_number}, index #{index}: unrecognized format"
              next
            end
            
            # Create an output filename with the line number and image index
            output_filename = "line_#{line_number}_image_#{index}.#{image_format}"
            output_path = File.join(output_directory, output_filename)
            
            # Write the image data to the output file
            File.binwrite(output_path, image_data)
            puts "Extracted image to: #{output_path}"
            total_images_extracted += 1
          rescue => e
            STDERR.puts "Error decoding image at line #{line_number}, index #{index}: #{e.message}"
          end
        end
      end
    rescue JSON::ParserError => e
      STDERR.puts "Error parsing JSON at line #{line_number}: #{e.message}"
    rescue => e
      STDERR.puts "Unexpected error at line #{line_number}: #{e.message}"
    end
  end

  puts "Extraction complete. #{total_images_extracted} images extracted to #{output_directory}"
end

def determine_image_format(image_data)
  # Check magic bytes to determine image format
  case
  when image_data.start_with?("\x89PNG\r\n\x1a\n".force_encoding('BINARY'))
    'png'
  when image_data.start_with?("\xff\xd8\xff".force_encoding('BINARY'))
    'jpg'
  when image_data.start_with?('GIF87a'.force_encoding('BINARY')), image_data.start_with?('GIF89a'.force_encoding('BINARY'))
    'gif'
  when image_data.start_with?('BM'.force_encoding('BINARY'))
    'bmp'
  when image_data.start_with?("\x49\x49\x2A\x00".force_encoding('BINARY')),
       image_data.start_with?("\x4D\x4D\x00\x2A".force_encoding('BINARY'))
    'tiff'
  when image_data.start_with?('RIFF'.force_encoding('BINARY')) && image_data[8, 4] == 'WEBP'.force_encoding('BINARY')
    'webp'
  else
    # Return nil if format cannot be determined (not a valid image)
    nil
  end
end

# Main execution
if ARGV.length != 2
  STDERR.puts "Usage: #{$0} <input.jsonl> <output_directory>"
  exit 1
end

jsonl_file_path = ARGV[0]
output_directory = ARGV[1]

extract_images_from_jsonl(jsonl_file_path, output_directory)
