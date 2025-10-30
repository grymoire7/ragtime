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
        file.read
      end
    rescue => e
      raise ExtractionError, "Error reading text file: #{e.message}"
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

    class UnsupportedFormatError < StandardError; end
    class ExtractionError < StandardError; end
  end
end
