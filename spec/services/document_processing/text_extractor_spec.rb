require "rails_helper"

RSpec.describe DocumentProcessing::TextExtractor do
  describe "#validate_utf8" do
    subject(:extractor) { described_class.new(document) }

    let(:document) { instance_double("Document", file: file_double, content_type: "text/plain") }
    let(:file_double) { instance_double("ActiveStorage::Blob") }

    context "when the text has valid UTF-8 encoding" do
      let(:valid_text) { "Hello, World!".encode("UTF-8") }

      it "returns the original text unchanged" do
        result = extractor.send(:validate_utf8, valid_text)
        expect(result).to eq("Hello, World!")
      end

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, valid_text)
        expect(result.valid_encoding?).to be true
      end
    end

    context "when the text contains valid multi-byte UTF-8 characters" do
      let(:unicode_text) { "Special chars: é, ñ, ü, 中文, 日本語, العربية" }

      it "returns the text with unicode characters preserved" do
        result = extractor.send(:validate_utf8, unicode_text)
        expect(result).to eq("Special chars: é, ñ, ü, 中文, 日本語, العربية")
      end

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, unicode_text)
        expect(result.valid_encoding?).to be true
      end
    end

    context "when the text contains emojis and symbols" do
      let(:emoji_text) { "Hello 🌍! Ruby 💎 is great 🎉" }

      it "returns the text with emojis preserved" do
        result = extractor.send(:validate_utf8, emoji_text)
        expect(result).to eq("Hello 🌍! Ruby 💎 is great 🎉")
      end

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, emoji_text)
        expect(result.valid_encoding?).to be true
      end
    end

    context "when the text is an empty string" do
      let(:empty_text) { "" }

      it "returns an empty string" do
        result = extractor.send(:validate_utf8, empty_text)
        expect(result).to eq("")
      end

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, empty_text)
        expect(result.valid_encoding?).to be true
      end
    end

    context "when the text contains invalid UTF-8 sequences that can be scrubbed" do
      let(:invalid_utf8_text) do
        text = "Hello \xFF\xFE World"
        text.force_encoding("UTF-8")
        text
      end

      it "returns a string with valid encoding after scrubbing" do
        result = extractor.send(:validate_utf8, invalid_utf8_text)
        expect(result.valid_encoding?).to be true
      end

      it "replaces invalid characters with the replacement character" do
        result = extractor.send(:validate_utf8, invalid_utf8_text)
        expect(result).to include("Hello")
        expect(result).to include("World")
        expect(result).to include("�")
      end

      it "does not raise an error" do
        expect {
          extractor.send(:validate_utf8, invalid_utf8_text)
        }.not_to raise_error
      end
    end

    context "when the text has valid encoding reported by valid_encoding?" do
      let(:clean_text) { "Simple ASCII text" }

      it "does not call scrub on the text" do
        expect(clean_text).not_to receive(:scrub)
        extractor.send(:validate_utf8, clean_text)
      end

      it "returns the exact same content" do
        result = extractor.send(:validate_utf8, clean_text)
        expect(result).to eq(clean_text)
      end
    end

    context "when the text contains a mix of valid and invalid UTF-8 sequences" do
      let(:mixed_text) do
        valid_part = "Valid text "
        invalid_bytes = "\xFF\xFE".force_encoding("UTF-8")
        more_valid = " more valid text"
        (valid_part + invalid_bytes + more_valid).force_encoding("UTF-8")
      end

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, mixed_text)
        expect(result.valid_encoding?).to be true
      end

      it "preserves the valid portions of the text" do
        result = extractor.send(:validate_utf8, mixed_text)
        expect(result).to include("Valid text")
        expect(result).to include("more valid text")
      end

      it "replaces invalid sequences with replacement characters" do
        result = extractor.send(:validate_utf8, mixed_text)
        expect(result).to include("�")
      end
    end

    context "when the text is already valid but scrub is called" do
      let(:valid_text) { "No issues here" }

      it "returns a string that passes valid_encoding? check" do
        result = extractor.send(:validate_utf8, valid_text)
        expect(result.valid_encoding?).to be true
      end

      it "returns the original content" do
        result = extractor.send(:validate_utf8, valid_text)
        expect(result).to eq("No issues here")
      end
    end

    context "when the text contains null bytes" do
      let(:text_with_null) { "Hello\x00World" }

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, text_with_null)
        expect(result.valid_encoding?).to be true
      end

      it "preserves null bytes since they are valid UTF-8" do
        result = extractor.send(:validate_utf8, text_with_null)
        expect(result).to include("Hello")
        expect(result).to include("World")
      end
    end

    context "when the text contains newlines and special whitespace" do
      let(:text_with_whitespace) { "Line one\nLine two\r\nLine three\tTabbed" }

      it "returns the text with whitespace preserved" do
        result = extractor.send(:validate_utf8, text_with_whitespace)
        expect(result).to eq("Line one\nLine two\r\nLine three\tTabbed")
      end

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, text_with_whitespace)
        expect(result.valid_encoding?).to be true
      end
    end

    context "when the text encoding is ASCII (subset of UTF-8)" do
      let(:ascii_text) { "Pure ASCII text 123".encode("ASCII") }

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, ascii_text)
        expect(result.valid_encoding?).to be true
      end

      it "returns the same content" do
        result = extractor.send(:validate_utf8, ascii_text)
        expect(result).to eq("Pure ASCII text 123")
      end
    end

    context "when the text is a long string with valid UTF-8" do
      let(:long_text) { "A" * 100_000 }

      it "handles large text without error" do
        expect {
          extractor.send(:validate_utf8, long_text)
        }.not_to raise_error
      end

      it "returns the full text" do
        result = extractor.send(:validate_utf8, long_text)
        expect(result.length).to eq(100_000)
      end

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, long_text)
        expect(result.valid_encoding?).to be true
      end
    end

    context "when validating return value type" do
      let(:text) { "Some text" }

      it "returns a String" do
        result = extractor.send(:validate_utf8, text)
        expect(result).to be_a(String)
      end
    end

    context "when text has valid encoding and scrub is applied" do
      let(:valid_text) { "Valid UTF-8: café" }

      it "the replacement character is not introduced" do
        result = extractor.send(:validate_utf8, valid_text)
        expect(result).not_to include("�")
      end
    end

    context "when the text contains only invalid bytes" do
      let(:all_invalid_text) do
        "\xFF\xFE\xFD".force_encoding("UTF-8")
      end

      it "returns a string with valid encoding" do
        result = extractor.send(:validate_utf8, all_invalid_text)
        expect(result.valid_encoding?).to be true
      end

      it "replaces all invalid bytes with replacement characters" do
        result = extractor.send(:validate_utf8, all_invalid_text)
        expect(result).to include("�")
      end

      it "does not raise an error" do
        expect {
          extractor.send(:validate_utf8, all_invalid_text)
        }.not_to raise_error
      end
    end

    context "when integrated with extract_from_text" do
      let(:temp_file) { instance_double("Tempfile") }
      let(:valid_text) { "Valid text content" }

      before do
        allow(file_double).to receive(:open).and_yield(temp_file)
        allow(temp_file).to receive(:set_encoding)
        allow(temp_file).to receive(:read).and_return(valid_text)
      end

      it "processes text through validate_utf8 without error" do
        expect {
          extractor.send(:extract_from_text)
        }.not_to raise_error
      end

      it "returns valid text" do
        result = extractor.send(:extract_from_text)
        expect(result).to eq("Valid text content")
      end
    end

    context "when integrated with extract_from_markdown" do
      let(:document) { instance_double("Document", file: file_double, content_type: "text/markdown") }
      let(:temp_file) { instance_double("Tempfile") }
      let(:markdown_text) { "# Heading\n\nSome **markdown** content" }

      before do
        allow(file_double).to receive(:open).and_yield(temp_file)
        allow(temp_file).to receive(:set_encoding)
        allow(temp_file).to receive(:read).and_return(markdown_text)
      end

      it "processes markdown text through validate_utf8 without error" do
        expect {
          extractor.send(:extract_from_markdown)
        }.not_to raise_error
      end

      it "returns valid markdown text" do
        result = extractor.send(:extract_from_markdown)
        expect(result).to eq("# Heading\n\nSome **markdown** content")
      end
    end
  end
end
