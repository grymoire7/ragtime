class ProcessDocumentJob < ApplicationJob
  queue_as :default

  # Process a document: extract text, chunk it, generate embeddings, and store chunks
  # @param document_id [Integer] the ID of the document to process
  def perform(document_id)
    document = Document.find(document_id)

    # Update status to processing
    document.update!(status: :processing)

    begin
      # Step 1: Extract text from the document
      text = DocumentProcessing::TextExtractor.extract(document)

      if text.blank?
        raise ProcessingError, "No text could be extracted from document"
      end

      # Step 2: Chunk the text into smaller pieces
      chunk_data = DocumentProcessing::TextChunker.chunk(text)

      if chunk_data.empty?
        raise ProcessingError, "No chunks could be created from extracted text"
      end

      # Step 3: Generate embeddings for all chunks
      chunk_texts = chunk_data.map { |c| c[:text] }
      embeddings = DocumentProcessing::EmbeddingGenerator.generate_batch(chunk_texts)

      # Step 4: Create chunk records with embeddings
      chunk_data.each_with_index do |chunk_info, index|
        document.chunks.create!(
          content: chunk_info[:text],
          position: index,
          token_count: chunk_info[:token_count],
          embedding: embeddings[index]
        )
      end

      # Mark document as completed
      document.update!(
        status: :completed,
        processed_at: Time.current
      )

      Rails.logger.info "Successfully processed document #{document.id}: #{document.chunks.count} chunks created"
    rescue => e
      # Mark document as failed with error message and log the error
      error_message = case e
      when ProcessingError
        e.message
      when DocumentProcessing::TextExtractor::ExtractionError
        "Unable to extract text from document. The file may be corrupted or in an unsupported format."
      else
        "An unexpected error occurred while processing the document: #{e.class.name}"
      end

      document.update!(
        status: :failed,
        error_message: error_message
      )

      Rails.logger.error "Failed to process document #{document.id}: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      # Re-raise the error so the job system can handle retries if configured
      raise e
    end
  end

  class ProcessingError < StandardError; end
end
