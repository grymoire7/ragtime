require 'rails_helper'

RSpec.describe DocumentProcessing::TextExtractor do
  let(:document) { create(:document) }

  describe ".extract" do
    it "delegates to instance method" do
      expect_any_instance_of(described_class).to receive(:extract).and_return("extracted text")
      result = described_class.extract(document)
      expect(result).to eq("extracted text")
    end
  end

  describe "#extract" do
    subject(:extractor) { described_class.new(document) }

    context "with unsupported format" do
      let(:document) { build(:document, content_type: "image/png") }

      it "raises UnsupportedFormatError" do
        expect {
          extractor.extract
        }.to raise_error(DocumentProcessing::TextExtractor::UnsupportedFormatError, /Unsupported document format/)
      end
    end

    context "with PDF document" do
      let(:document) { create(:document, content_type: "application/pdf") }

      before do
        # Mock PDF::Reader
        pdf_reader = double("PDF::Reader")
        page1 = double("Page", text: "Content from page 1")
        page2 = double("Page", text: "Content from page 2")
        allow(pdf_reader).to receive(:pages).and_return([page1, page2])
        allow(PDF::Reader).to receive(:new).and_return(pdf_reader)
      end

      it "extracts text from PDF" do
        result = extractor.extract
        expect(result).to include("Content from page 1")
        expect(result).to include("Content from page 2")
      end

      it "strips whitespace from result" do
        result = extractor.extract
        expect(result).not_to start_with(" ")
        expect(result).not_to end_with(" ")
      end

      context "when PDF is malformed" do
        before do
          allow(PDF::Reader).to receive(:new).and_raise(PDF::Reader::MalformedPDFError.new("Bad PDF"))
        end

        it "raises ExtractionError" do
          expect {
            extractor.extract
          }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError, /Failed to read PDF/)
        end
      end

      context "when PDF extraction fails" do
        before do
          allow(PDF::Reader).to receive(:new).and_raise(StandardError.new("Unknown error"))
        end

        it "raises ExtractionError" do
          expect {
            extractor.extract
          }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError, /Error extracting text from PDF/)
        end
      end
    end

    context "with text document" do
      it "extracts text from plain text file" do
        # Create document with specific content
        document = create(:document, :text_file)
        document.file.attach(
          io: StringIO.new("Plain text content from file"),
          filename: "test.txt",
          content_type: "text/plain"
        )
        extractor = described_class.new(document)

        result = extractor.extract
        expect(result).to eq("Plain text content from file")
      end

      it "strips whitespace from result" do
        # Create document with whitespace content
        document = create(:document, :text_file)
        document.file.attach(
          io: StringIO.new("  Text with spaces  "),
          filename: "test.txt",
          content_type: "text/plain"
        )
        extractor = described_class.new(document)

        result = extractor.extract
        expect(result).to eq("Text with spaces")
      end

      context "when file reading fails" do
        it "raises ExtractionError" do
          document = create(:document, :text_file)
          extractor = described_class.new(document)

          # Stub file.read to raise an error within the open block
          allow_any_instance_of(Tempfile).to receive(:read).and_raise(StandardError.new("File error"))

          expect {
            extractor.extract
          }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError, /Error reading text file/)
        end
      end

      context "when text file has encoding issues" do
        it "cleans invalid UTF-8 sequences and continues" do
          document = create(:document, :text_file)
          document.file.attach(
            io: StringIO.new("Valid text\xFF\xFE Invalid bytes"),
            filename: "test.txt",
            content_type: "text/plain"
          )
          extractor = described_class.new(document)

          result = extractor.extract
          expect(result).to include("Valid text")
          expect(result).to include("�") # Should contain replacement character
          expect(result).to be_valid_encoding
        end
      end
    end

    context "with DOCX document" do
      let(:document) { create(:document, :docx_file) }

      before do
        # Mock Docx::Document
        docx_doc = double("Docx::Document")
        para1 = double("Paragraph", text: "First paragraph")
        para2 = double("Paragraph", text: "Second paragraph")
        allow(docx_doc).to receive(:paragraphs).and_return([para1, para2])
        allow(Docx::Document).to receive(:open).and_return(docx_doc)
      end

      it "extracts text from DOCX" do
        result = extractor.extract
        expect(result).to include("First paragraph")
        expect(result).to include("Second paragraph")
      end

      it "strips whitespace from result" do
        result = extractor.extract
        expect(result).not_to start_with(" ")
        expect(result).not_to end_with(" ")
      end

      context "when DOCX extraction fails" do
        before do
          allow(Docx::Document).to receive(:open).and_raise(StandardError.new("DOCX error"))
        end

        it "raises ExtractionError" do
          expect {
            extractor.extract
          }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError, /Error extracting text from DOCX/)
        end
      end
    end

    context "with markdown document" do
      it "extracts text from markdown file" do
        # Create document with markdown content
        document = create(:document, content_type: "text/markdown")
        document.file.attach(
          io: StringIO.new("# Heading\n\nSome **bold** text and a [link](http://example.com)."),
          filename: "test.md",
          content_type: "text/markdown"
        )
        extractor = described_class.new(document)

        result = extractor.extract
        expect(result).to eq("# Heading\n\nSome **bold** text and a [link](http://example.com).")
      end

      it "strips whitespace from result" do
        # Create document with whitespace content
        document = create(:document, content_type: "text/markdown")
        document.file.attach(
          io: StringIO.new("  Markdown content with spaces  "),
          filename: "test.md",
          content_type: "text/markdown"
        )
        extractor = described_class.new(document)

        result = extractor.extract
        expect(result).to eq("Markdown content with spaces")
      end

      context "when markdown file reading fails" do
        it "raises ExtractionError" do
          document = create(:document, content_type: "text/markdown")
          extractor = described_class.new(document)

          # Stub file.read to raise an error within the open block
          allow_any_instance_of(Tempfile).to receive(:read).and_raise(StandardError.new("File error"))

          expect {
            extractor.extract
          }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError, /Error reading markdown file/)
        end
      end

      context "when markdown file has encoding issues" do
        it "cleans invalid UTF-8 sequences and continues" do
          document = create(:document, content_type: "text/markdown")
          document.file.attach(
            io: StringIO.new("Valid text\xFF\xFE Invalid bytes"),
            filename: "test.md",
            content_type: "text/markdown"
          )
          extractor = described_class.new(document)

          result = extractor.extract
          expect(result).to include("Valid text")
          expect(result).to include("�") # Should contain replacement character
          expect(result).to be_valid_encoding
        end
      end
    end
  end

  describe "supported formats" do
    it "supports PDF" do
      document = build(:document, content_type: "application/pdf")
      extractor = described_class.new(document)
      expect { extractor.extract }.not_to raise_error(DocumentProcessing::TextExtractor::UnsupportedFormatError)
    end

    it "supports plain text" do
      document = build(:document, content_type: "text/plain")
      extractor = described_class.new(document)
      expect { extractor.extract }.not_to raise_error(DocumentProcessing::TextExtractor::UnsupportedFormatError)
    end

    it "supports DOCX" do
      document = build(:document, content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
      extractor = described_class.new(document)
      expect { extractor.extract }.not_to raise_error(DocumentProcessing::TextExtractor::UnsupportedFormatError)
    end

    it "supports markdown" do
      document = build(:document, content_type: "text/markdown")
      extractor = described_class.new(document)
      expect { extractor.extract }.not_to raise_error(DocumentProcessing::TextExtractor::UnsupportedFormatError)
    end
  end
end
