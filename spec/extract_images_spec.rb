require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'base64'

RSpec.describe 'Image Extraction Script' do
  let(:script_path) { File.join(File.dirname(__FILE__), '../bin/extract_images.rb') }
  let(:test_image_path) { File.join(File.dirname(__FILE__), 'apple.jpg') }

  before do
    # Ensure the test image exists
    expect(File.exist?(test_image_path)).to be true
  end

  it 'extracts images from a JSONL file with base64-encoded images' do
    # Create a temporary JSONL file with a base64-encoded image
    temp_jsonl = Tempfile.new(['test', '.jsonl'])
    begin
      # Read test image and encode it
      image_data = File.read(test_image_path, mode: 'rb')
      base64_image = Base64.encode64(image_data)

      # Create JSONL content with the image
      jsonl_content = {
        id: 'test1',
        texts: { content: 'Test with image' },
        images: [base64_image]
      }.to_json

      temp_jsonl.write(jsonl_content)
      temp_jsonl.close

      # Create a temporary output directory
      output_dir = Dir.mktmpdir('image_extraction_test_')

      begin
        # Run the extraction script
        result = system('bundle', 'exec', 'ruby', script_path, temp_jsonl.path, output_dir)

        # Verify the script executed successfully
        expect(result).to be true

        # Verify that an image was extracted
        extracted_files = Dir.glob(File.join(output_dir, '*.jpg'))
        expect(extracted_files.length).to eq(1)

        # Verify the extracted file is a valid image
        extracted_file = extracted_files.first
        expect(File.exist?(extracted_file)).to be true
        expect(File.size(extracted_file)).to be > 0
        
        # Verify that it's the same image by comparing content
        extracted_image_data = File.read(extracted_file, mode: 'rb')
        expect(extracted_image_data).to eq(image_data)
      ensure
        # Clean up the output directory
        FileUtils.rm_rf(output_dir)
      end
    ensure
      # Clean up temp file
      temp_jsonl.unlink
    end
  end

  it 'handles multiple images in a single JSONL line' do
    # Create a temporary JSONL file with multiple base64-encoded images
    temp_jsonl = Tempfile.new(['test_multi', '.jsonl'])
    begin
      # Read test image and encode it
      image_data = File.read(test_image_path, mode: 'rb')
      base64_image = Base64.encode64(image_data)

      # Create JSONL content with multiple images
      jsonl_content = {
        id: 'test1',
        texts: { content: 'Test with multiple images' },
        images: [base64_image, base64_image]  # Two identical images
      }.to_json

      temp_jsonl.write(jsonl_content)
      temp_jsonl.close

      # Create a temporary output directory
      output_dir = Dir.mktmpdir('image_extraction_test_multi_')

      begin
        # Run the extraction script
        result = system('bundle', 'exec', 'ruby', script_path, temp_jsonl.path, output_dir)

        # Verify the script executed successfully
        expect(result).to be true

        # Verify that both images were extracted
        extracted_files = Dir.glob(File.join(output_dir, '*.jpg'))
        expect(extracted_files.length).to eq(2)

        # Verify both extracted files are valid images
        extracted_files.each do |file|
          expect(File.exist?(file)).to be true
          expect(File.size(file)).to be > 0
          # Verify that they're the same as the original image
          extracted_image_data = File.read(file, mode: 'rb')
          expect(extracted_image_data).to eq(image_data)
        end
      ensure
        # Clean up the output directory
        FileUtils.rm_rf(output_dir)
      end
    ensure
      # Clean up temp file
      temp_jsonl.unlink
    end
  end

  it 'handles multiple JSONL lines with images' do
    # Create a temporary JSONL file with multiple lines containing images
    temp_jsonl = Tempfile.new(['test_multi_line', '.jsonl'])
    begin
      # Read test image and encode it
      image_data = File.read(test_image_path, mode: 'rb')
      base64_image = Base64.encode64(image_data)

      # Create multiple JSONL lines
      line1 = {
        id: 'test1',
        texts: { content: 'First line with image' },
        images: [base64_image]
      }.to_json

      line2 = {
        id: 'test2',
        texts: { content: 'Second line with image' },
        images: [base64_image]
      }.to_json

      temp_jsonl.write(line1 + "\n")
      temp_jsonl.write(line2 + "\n")
      temp_jsonl.close

      # Create a temporary output directory
      output_dir = Dir.mktmpdir('image_extraction_test_multi_line_')

      begin
        # Run the extraction script
        result = system('bundle', 'exec', 'ruby', script_path, temp_jsonl.path, output_dir)

        # Verify the script executed successfully
        expect(result).to be true

        # Verify that images from both lines were extracted
        extracted_files = Dir.glob(File.join(output_dir, '*.jpg'))
        expect(extracted_files.length).to eq(2)

        # Verify both extracted files are valid images
        extracted_files.each do |file|
          expect(File.exist?(file)).to be true
          expect(File.size(file)).to be > 0
          # Verify that they're the same as the original image
          extracted_image_data = File.read(file, mode: 'rb')
          expect(extracted_image_data).to eq(image_data)
        end

        # Check that the filenames indicate they came from different lines
        filenames = extracted_files.map { |f| File.basename(f) }
        expect(filenames).to include("line_1_image_0.jpg")
        expect(filenames).to include("line_2_image_0.jpg")
      ensure
        # Clean up the output directory
        FileUtils.rm_rf(output_dir)
      end
    ensure
      # Clean up temp file
      temp_jsonl.unlink
    end
  end

  it 'handles JSONL files with no images' do
    # Create a temporary JSONL file without images
    temp_jsonl = Tempfile.new(['test_no_images', '.jsonl'])
    begin
      # Create JSONL content without images
      jsonl_content = {
        id: 'test1',
        texts: { content: 'Test without images' }
      }.to_json

      temp_jsonl.write(jsonl_content)
      temp_jsonl.close

      # Create a temporary output directory
      output_dir = Dir.mktmpdir('image_extraction_test_no_images_')

      begin
        # Run the extraction script
        result = system('bundle', 'exec', 'ruby', script_path, temp_jsonl.path, output_dir)

        # Verify the script executed successfully
        expect(result).to be true

        # Verify that no images were extracted
        extracted_files = Dir.glob(File.join(output_dir, '*.*'))
        expect(extracted_files.length).to eq(0)
      ensure
        # Clean up the output directory
        FileUtils.rm_rf(output_dir)
      end
    ensure
      # Clean up temp file
      temp_jsonl.unlink
    end
  end

  it 'handles invalid base64 data gracefully' do
    # Create a temporary JSONL file with invalid base64 data
    temp_jsonl = Tempfile.new(['test_invalid_base64', '.jsonl'])
    begin
      # Create JSONL content with invalid base64
      jsonl_content = {
        id: 'test1',
        texts: { content: 'Test with invalid base64' },
        images: ['invalid_base64_data!@#$%^&*()']  # Invalid base64
      }.to_json

      temp_jsonl.write(jsonl_content)
      temp_jsonl.close

      # Create a temporary output directory
      output_dir = Dir.mktmpdir('image_extraction_test_invalid_base64_')

      begin
        # Run the extraction script and capture output
        result = system('bundle', 'exec', 'ruby', script_path, temp_jsonl.path, output_dir)

        # The script should handle invalid base64 gracefully
        # It should still complete successfully even with errors
        extracted_files = Dir.glob(File.join(output_dir, '*.*'))
        expect(extracted_files.length).to eq(0)  # No files should be extracted
      ensure
        # Clean up the output directory
        FileUtils.rm_rf(output_dir)
      end
    ensure
      # Clean up temp file
      temp_jsonl.unlink
    end
  end

  it 'shows error message with no arguments' do
    # Test the script with no arguments
    expect do
      system('bundle', 'exec', 'ruby', script_path)
    end
  end
end