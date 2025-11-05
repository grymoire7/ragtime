module DocumentProcessing
  class TextExtractor
    # Extract text content from a document file
    # @param document [Document] the document model instance with attached file
    # @return [String] extracted text content
    # @raises [UnsupportedFormatError] if the document format is not supported
    # @raises [ExtractionError] if extraction fails
    def self.extract(document)
      new(document).extract
    end

    def initialize(document)
      @document = document
    end

    def extract
      unless @document.supported_format?
        raise UnsupportedFormatError, "Unsupported document format: #{@document.content_type}"
      end

      text = case @document.content_type
      when "application/pdf"
        extract_from_pdf
      when "text/plain"
        extract_from_text
      when "text/markdown"
        extract_from_markdown
      when "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        extract_from_docx
      else
        raise UnsupportedFormatError, "Unsupported document format: #{@document.content_type}"
      end

      text.strip
    end

    private

    def extract_from_pdf
      require "pdf-reader"

      @document.file.open do |file|
        reader = PDF::Reader.new(file.path)
        reader.pages.map(&:text).join("\n\n")
      end
    rescue PDF::Reader::MalformedPDFError => e
      raise ExtractionError, "Failed to read PDF: #{e.message}"
    rescue => e
      raise ExtractionError, "Error extracting text from PDF: #{e.message}"
    end

    def extract_from_text
      @document.file.open do |file|
        file.set_encoding("UTF-8")
        text = file.read
        validate_utf8(text)
      end
    rescue EncodingError => e
      raise ExtractionError, "Text file contains invalid UTF-8 encoding: #{e.message}"
    rescue => e
      raise ExtractionError, "Error reading text file: #{e.message}"
    end

    def extract_from_markdown
      @document.file.open do |file|
        file.set_encoding("UTF-8")
        text = file.read
        validate_utf8(text)
      end
    rescue EncodingError => e
      raise ExtractionError, "Markdown file contains invalid UTF-8 encoding: #{e.message}"
    rescue => e
      raise ExtractionError, "Error reading markdown file: #{e.message}"
    end

    def extract_from_docx
      require "docx"

      @document.file.open do |file|
        doc = Docx::Document.open(file.path)
        doc.paragraphs.map(&:text).join("\n\n")
      end
    rescue => e
      raise ExtractionError, "Error extracting text from DOCX: #{e.message}"
    end

    # Validate that text contains valid UTF-8 encoding
    def validate_utf8(text)
      # Check if text has valid UTF-8 encoding
      unless text.valid_encoding?
        # Use scrub to clean up invalid UTF-8 sequences
        text = text.scrub("�") # Replace invalid chars with replacement character
        # If still invalid, raise an error
        unless text.valid_encoding?
          raise EncodingError, "File contains invalid UTF-8 byte sequences that cannot be cleaned"
        end
      end
      text
    end

    class UnsupportedFormatError < StandardError; end
    class ExtractionError < StandardError; end
  end
end
