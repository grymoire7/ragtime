module DocumentProcessing
  class TextChunker
    # Default chunk size in tokens (roughly 600-800 words)
    DEFAULT_CHUNK_SIZE = 800
    # Overlap between chunks to maintain context
    DEFAULT_OVERLAP = 200

    # Chunk text into smaller pieces with overlap
    # @param text [String] the text to chunk
    # @param chunk_size [Integer] target size in tokens
    # @param overlap [Integer] number of tokens to overlap between chunks
    # @return [Array<Hash>] array of hashes with :text and :token_count keys
    def self.chunk(text, chunk_size: DEFAULT_CHUNK_SIZE, overlap: DEFAULT_OVERLAP)
      new(text, chunk_size, overlap).chunk
    end

    def initialize(text, chunk_size, overlap)
      @text = text
      @chunk_size = chunk_size
      @overlap = overlap
      # Use cl100k_base encoding for token counting (used by GPT-4/GPT-3.5-turbo)
      # Note: This is an approximation for non-OpenAI models (Gemma, Claude, etc.)
      # but provides reasonable chunk sizing since most tokenizers produce similar counts.
      # The overlap buffer ensures we don't lose context even with slight variations.
      @encoder = Tiktoken.get_encoding("cl100k_base")
    end

    def chunk
      return [] if @text.blank?

      # Split text into paragraphs first
      paragraphs = @text.split(/\n\n+/).map(&:strip).reject(&:blank?)

      chunks = []
      current_chunk = []
      current_tokens = 0

      paragraphs.each do |paragraph|
        paragraph_tokens = count_tokens(paragraph)

        # If a single paragraph is larger than chunk_size, split it further
        if paragraph_tokens > @chunk_size
          # Flush current chunk if any
          if current_chunk.any?
            chunks << build_chunk(current_chunk.join("\n\n"))
            current_chunk = []
            current_tokens = 0
          end

          # Split large paragraph into sentences
          chunks.concat(split_large_paragraph(paragraph))
          next
        end

        # If adding this paragraph would exceed chunk_size, start a new chunk
        if current_tokens + paragraph_tokens > @chunk_size && current_chunk.any?
          chunks << build_chunk(current_chunk.join("\n\n"))

          # Start new chunk with overlap from previous chunk
          overlap_text = get_overlap_text(current_chunk.join("\n\n"))
          current_chunk = overlap_text.present? ? [overlap_text] : []
          current_tokens = overlap_text.present? ? count_tokens(overlap_text) : 0
        end

        current_chunk << paragraph
        current_tokens += paragraph_tokens
      end

      # Add the last chunk if any content remains
      if current_chunk.any?
        chunks << build_chunk(current_chunk.join("\n\n"))
      end

      chunks
    end

    private

    def count_tokens(text)
      @encoder.encode(text).length
    end

    def build_chunk(text)
      {
        text: text,
        token_count: count_tokens(text)
      }
    end

    def get_overlap_text(text)
      tokens = @encoder.encode(text)
      return "" if tokens.length < @overlap

      # Get the last @overlap tokens
      overlap_tokens = tokens.last(@overlap)
      overlap_text = @encoder.decode(overlap_tokens)

      # Try to start at a sentence boundary
      if overlap_text.include?(". ")
        sentences = overlap_text.split(/\. /)
        # Take the last complete sentence(s) that fit in the overlap
        sentences.last(2).join(". ")
      else
        overlap_text
      end
    end

    def split_large_paragraph(paragraph)
      # Split by sentence boundaries
      sentences = paragraph.split(/(?<=[.!?])\s+/)
      chunks = []
      current_chunk = []
      current_tokens = 0

      sentences.each do |sentence|
        sentence_tokens = count_tokens(sentence)

        # If a single sentence is still too large, split by words
        if sentence_tokens > @chunk_size
          if current_chunk.any?
            chunks << build_chunk(current_chunk.join(" "))
            current_chunk = []
            current_tokens = 0
          end

          chunks.concat(split_large_sentence(sentence))
          next
        end

        if current_tokens + sentence_tokens > @chunk_size && current_chunk.any?
          chunks << build_chunk(current_chunk.join(" "))

          overlap_text = get_overlap_text(current_chunk.join(" "))
          current_chunk = overlap_text.present? ? [overlap_text] : []
          current_tokens = overlap_text.present? ? count_tokens(overlap_text) : 0
        end

        current_chunk << sentence
        current_tokens += sentence_tokens
      end

      if current_chunk.any?
        chunks << build_chunk(current_chunk.join(" "))
      end

      chunks
    end

    def split_large_sentence(sentence)
      # Last resort: split by words
      words = sentence.split(/\s+/)
      chunks = []
      current_chunk = []
      current_tokens = 0

      words.each do |word|
        word_tokens = count_tokens(word)

        if current_tokens + word_tokens > @chunk_size && current_chunk.any?
          chunks << build_chunk(current_chunk.join(" "))
          current_chunk = []
          current_tokens = 0
        end

        current_chunk << word
        current_tokens += word_tokens
      end

      if current_chunk.any?
        chunks << build_chunk(current_chunk.join(" "))
      end

      chunks
    end
  end
end
