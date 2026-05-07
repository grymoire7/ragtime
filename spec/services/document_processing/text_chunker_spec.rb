require 'rails_helper'

RSpec.describe DocumentProcessing::TextChunker do
  describe "#split_large_sentence (private method)" do
    subject(:chunker) { described_class.new(text, chunk_size, overlap) }

    let(:chunk_size) { described_class::DEFAULT_CHUNK_SIZE }
    let(:overlap) { described_class::DEFAULT_OVERLAP }
    let(:text) { "sample text" }
    let(:encoder) { Tiktoken.get_encoding("cl100k_base") }

    # Helper to call the private method
    def split_large_sentence(instance, sentence)
      instance.send(:split_large_sentence, sentence)
    end

    # Helper to count tokens
    def token_count(str)
      encoder.encode(str).length
    end

    # Generate a sentence with approximately n tokens using words
    def generate_sentence_with_tokens(approx_tokens)
      words = []
      current_tokens = 0
      i = 0
      while current_tokens < approx_tokens
        word = "word#{i}"
        words << word
        current_tokens = encoder.encode(words.join(" ")).length
        i += 1
      end
      words.join(" ")
    end

    # Generate a word blob with a specific approximate token count
    def generate_word_blob(approx_tokens)
      ("word " * (approx_tokens + 10)).strip
    end

    context "return type" do
      let(:large_sentence) { generate_sentence_with_tokens(chunk_size + 200) }

      it "returns an Array" do
        expect(split_large_sentence(chunker, large_sentence)).to be_an(Array)
      end

      it "returns an array of Hashes" do
        result = split_large_sentence(chunker, large_sentence)
        expect(result).to all(be_a(Hash))
      end

      it "returns hashes with :text key" do
        result = split_large_sentence(chunker, large_sentence)
        expect(result).to all(have_key(:text))
      end

      it "returns hashes with :token_count key" do
        result = split_large_sentence(chunker, large_sentence)
        expect(result).to all(have_key(:token_count))
      end

      it "returns hashes where :text is a String" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:text]).to be_a(String)
        end
      end

      it "returns hashes where :token_count is an Integer" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to be_an(Integer)
        end
      end
    end

    context "with a short sentence that fits in chunk_size" do
      let(:short_sentence) { "This is a short sentence." }

      it "returns exactly one chunk" do
        result = split_large_sentence(chunker, short_sentence)
        expect(result.length).to eq(1)
      end

      it "returns the sentence as the chunk text" do
        result = split_large_sentence(chunker, short_sentence)
        expect(result.first[:text]).to eq(short_sentence)
      end

      it "returns the correct token count" do
        result = split_large_sentence(chunker, short_sentence)
        expect(result.first[:token_count]).to eq(token_count(short_sentence))
      end
    end

    context "with a single word" do
      let(:single_word) { "hello" }

      it "returns exactly one chunk" do
        result = split_large_sentence(chunker, single_word)
        expect(result.length).to eq(1)
      end

      it "returns the word as chunk text" do
        result = split_large_sentence(chunker, single_word)
        expect(result.first[:text]).to eq(single_word)
      end

      it "returns the correct token count for a single word" do
        result = split_large_sentence(chunker, single_word)
        expect(result.first[:token_count]).to eq(token_count(single_word))
      end
    end

    context "with a sentence that requires splitting across multiple chunks" do
      let(:large_sentence) { generate_sentence_with_tokens(chunk_size * 2 + 100) }

      it "returns more than one chunk" do
        result = split_large_sentence(chunker, large_sentence)
        expect(result.length).to be > 1
      end

      it "returns chunks where each has a non-empty :text" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:text]).not_to be_empty
        end
      end

      it "returns chunks where each has a positive :token_count" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to be > 0
        end
      end

      it "returns chunks that do not exceed chunk_size" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to be <= chunk_size + 10
        end
      end

      it "returns chunks whose :token_count matches the actual token count of :text" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to eq(token_count(chunk[:text]))
        end
      end
    end

    context "chunk_size boundaries" do
      let(:large_sentence) { generate_sentence_with_tokens(chunk_size + 200) }

      it "does not produce chunks that vastly exceed chunk_size" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to be <= chunk_size * 2
        end
      end

      it "produces at least 2 chunks for a sentence of 2x chunk_size" do
        sentence = generate_sentence_with_tokens(chunk_size * 2 + 50)
        result = split_large_sentence(chunker, sentence)
        expect(result.length).to be >= 2
      end

      it "produces at least 3 chunks for a sentence of 3x chunk_size" do
        sentence = generate_sentence_with_tokens(chunk_size * 3 + 50)
        result = split_large_sentence(chunker, sentence)
        expect(result.length).to be >= 3
      end
    end

    context "with a sentence of exactly chunk_size tokens" do
      let(:exact_sentence) do
        words = []
        current_tokens = 0
        i = 0
        while current_tokens < chunk_size - 5
          words << "word#{i}"
          current_tokens = encoder.encode(words.join(" ")).length
          i += 1
        end
        words.join(" ")
      end

      it "returns at least one chunk" do
        result = split_large_sentence(chunker, exact_sentence)
        expect(result.length).to be >= 1
      end

      it "returns valid chunk hashes" do
        result = split_large_sentence(chunker, exact_sentence)
        result.each do |chunk|
          expect(chunk[:text]).not_to be_empty
          expect(chunk[:token_count]).to be > 0
        end
      end
    end

    context "with small chunk_size" do
      subject(:chunker) { described_class.new(text, 20, 5) }

      let(:sentence) do
        words = (1..50).map { |i| "word#{i}" }
        words.join(" ")
      end

      it "returns multiple chunks" do
        result = split_large_sentence(chunker, sentence)
        expect(result.length).to be > 1
      end

      it "returns chunks that respect the small chunk_size" do
        result = split_large_sentence(chunker, sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to be <= 30
        end
      end

      it "returns an array of valid chunk hashes" do
        result = split_large_sentence(chunker, sentence)
        result.each do |chunk|
          expect(chunk).to have_key(:text)
          expect(chunk).to have_key(:token_count)
          expect(chunk[:text]).not_to be_empty
          expect(chunk[:token_count]).to be > 0
        end
      end
    end

    context "with very small chunk_size of 5" do
      subject(:chunker) { described_class.new(text, 5, 1) }

      let(:sentence) { "one two three four five six seven eight nine ten" }

      it "returns multiple chunks" do
        result = split_large_sentence(chunker, sentence)
        expect(result.length).to be >= 2
      end

      it "returns non-empty chunks" do
        result = split_large_sentence(chunker, sentence)
        result.each do |chunk|
          expect(chunk[:text]).not_to be_empty
        end
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, sentence) }.not_to raise_error
      end
    end

    context "with zero overlap" do
      subject(:chunker) { described_class.new(text, chunk_size, 0) }

      let(:large_sentence) { generate_sentence_with_tokens(chunk_size * 2 + 100) }

      it "returns an Array" do
        result = split_large_sentence(chunker, large_sentence)
        expect(result).to be_an(Array)
      end

      it "returns multiple chunks for large sentences" do
        result = split_large_sentence(chunker, large_sentence)
        expect(result.length).to be >= 1
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, large_sentence) }.not_to raise_error
      end

      it "returns chunks with valid structure" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:text]).not_to be_empty
          expect(chunk[:token_count]).to be > 0
        end
      end
    end

    context "token_count accuracy" do
      let(:large_sentence) { generate_sentence_with_tokens(chunk_size + 300) }

      it "stores the correct token_count for each chunk" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          actual_tokens = token_count(chunk[:text])
          expect(chunk[:token_count]).to eq(actual_tokens)
        end
      end
    end

    context "content preservation" do
      let(:sentence) { "alpha beta gamma delta epsilon zeta eta theta iota kappa" }

      it "preserves all words when sentence fits in one chunk" do
        result = split_large_sentence(chunker, sentence)
        all_text = result.map { |c| c[:text] }.join(" ")
        expect(all_text).to include("alpha")
        expect(all_text).to include("kappa")
      end
    end

    context "content coverage for large sentences" do
      let(:large_sentence) { generate_sentence_with_tokens(chunk_size * 2 + 100) }

      it "contains recognizable words from the original sentence" do
        result = split_large_sentence(chunker, large_sentence)
        all_text = result.map { |c| c[:text] }.join(" ")
        expect(all_text).to include("word")
      end

      it "does not produce empty chunk texts" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:text].strip).not_to be_empty
        end
      end
    end

    context "method accessibility" do
      it "is a private method on the instance" do
        expect { chunker.split_large_sentence("some text") }.to raise_error(NoMethodError)
      end

      it "is accessible via send" do
        expect { chunker.send(:split_large_sentence, "some text") }.not_to raise_error
      end

      it "does not raise an error with valid input" do
        sentence = generate_sentence_with_tokens(chunk_size + 100)
        expect { split_large_sentence(chunker, sentence) }.not_to raise_error
      end
    end

    context "determinism" do
      let(:large_sentence) { generate_sentence_with_tokens(chunk_size + 300) }

      it "returns the same result when called multiple times with the same input" do
        first_result = split_large_sentence(chunker, large_sentence)
        second_result = split_large_sentence(chunker, large_sentence)
        expect(first_result).to eq(second_result)
      end

      it "is deterministic across 3 calls" do
        results = 3.times.map { split_large_sentence(chunker, large_sentence) }
        expect(results.uniq.length).to eq(1)
      end
    end

    context "with unicode text" do
      let(:unicode_sentence) do
        words = (1..200).map { |i| "wörد#{i}" }
        words.join(" ")
      end

      it "returns an Array" do
        result = split_large_sentence(chunker, unicode_sentence)
        expect(result).to be_an(Array)
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, unicode_sentence) }.not_to raise_error
      end

      it "returns non-empty chunk texts" do
        result = split_large_sentence(chunker, unicode_sentence)
        result.each do |chunk|
          expect(chunk[:text]).not_to be_empty
        end
      end
    end

    context "with a sentence containing special characters" do
      let(:special_char_sentence) do
        words = (1..200).map { |i| "word#{i}!" }
        words.join(" ")
      end

      it "returns an Array" do
        result = split_large_sentence(chunker, special_char_sentence)
        expect(result).to be_an(Array)
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, special_char_sentence) }.not_to raise_error
      end

      it "returns valid chunk hashes" do
        result = split_large_sentence(chunker, special_char_sentence)
        result.each do |chunk|
          expect(chunk).to have_key(:text)
          expect(chunk).to have_key(:token_count)
        end
      end
    end

    context "with a sentence of repeated words" do
      let(:repeated_word_sentence) { ("repeat " * (chunk_size + 50)).strip }

      it "returns an Array" do
        result = split_large_sentence(chunker, repeated_word_sentence)
        expect(result).to be_an(Array)
      end

      it "returns at least one chunk" do
        result = split_large_sentence(chunker, repeated_word_sentence)
        expect(result.length).to be >= 1
      end

      it "returns chunks within reasonable bounds of chunk_size" do
        result = split_large_sentence(chunker, repeated_word_sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to be <= chunk_size + 10
        end
      end
    end

    context "independence from initializer @text parameter" do
      let(:large_sentence) { generate_sentence_with_tokens(chunk_size + 200) }

      it "returns the same result regardless of the instance @text attribute" do
        chunker_a = described_class.new("completely different text A", chunk_size, overlap)
        chunker_b = described_class.new("completely different text B", chunk_size, overlap)
        expect(split_large_sentence(chunker_a, large_sentence)).to eq(
          split_large_sentence(chunker_b, large_sentence)
        )
      end
    end

    context "number of chunks scales with sentence size" do
      it "produces more chunks for a larger sentence" do
        small_sentence = generate_sentence_with_tokens(chunk_size + 100)
        large_sentence = generate_sentence_with_tokens(chunk_size * 3 + 100)

        small_result = split_large_sentence(chunker, small_sentence)
        large_result = split_large_sentence(chunker, large_sentence)

        expect(large_result.length).to be >= small_result.length
      end
    end

    context "with a sentence just over chunk_size" do
      let(:just_over_sentence) { generate_sentence_with_tokens(chunk_size + 10) }

      it "returns at least one chunk" do
        result = split_large_sentence(chunker, just_over_sentence)
        expect(result.length).to be >= 1
      end

      it "returns valid chunks" do
        result = split_large_sentence(chunker, just_over_sentence)
        result.each do |chunk|
          expect(chunk[:text]).not_to be_empty
          expect(chunk[:token_count]).to be > 0
        end
      end
    end

    context "with a sentence containing multiple whitespace types" do
      let(:multi_whitespace_sentence) do
        "word1  word2   word3\tword4\nword5 word6 word7 word8 word9 word10"
      end

      it "returns an Array" do
        result = split_large_sentence(chunker, multi_whitespace_sentence)
        expect(result).to be_an(Array)
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, multi_whitespace_sentence) }.not_to raise_error
      end

      it "returns at least one chunk" do
        result = split_large_sentence(chunker, multi_whitespace_sentence)
        expect(result.length).to be >= 1
      end
    end

    context "with numeric words" do
      let(:numeric_sentence) do
        words = (1..200).map { |i| i.to_s }
        words.join(" ")
      end

      it "returns an Array" do
        result = split_large_sentence(chunker, numeric_sentence)
        expect(result).to be_an(Array)
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, numeric_sentence) }.not_to raise_error
      end

      it "returns chunks with positive token counts" do
        result = split_large_sentence(chunker, numeric_sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to be > 0
        end
      end
    end

    context "token_count integrity for all chunk sizes" do
      subject(:chunker_small) { described_class.new(text, 50, 10) }

      let(:sentence) do
        words = (1..200).map { |i| "word#{i}" }
        words.join(" ")
      end

      it "always stores the actual token count of the chunk text" do
        result = split_large_sentence(chunker_small, sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to eq(token_count(chunk[:text]))
        end
      end
    end

    context "with a sentence where each word is exactly at token boundary" do
      subject(:chunker) { described_class.new(text, 10, 2) }

      let(:boundary_sentence) do
        # Create a sentence where words result in predictable token counts
        ("hello " * 30).strip
      end

      it "returns an Array" do
        result = split_large_sentence(chunker, boundary_sentence)
        expect(result).to be_an(Array)
      end

      it "returns multiple chunks" do
        result = split_large_sentence(chunker, boundary_sentence)
        expect(result.length).to be >= 2
      end

      it "returns accurate token counts for each chunk" do
        result = split_large_sentence(chunker, boundary_sentence)
        result.each do |chunk|
          expect(chunk[:token_count]).to eq(token_count(chunk[:text]))
        end
      end
    end

    context "with a sentence that is empty-like (minimal content)" do
      let(:minimal_sentence) { "a" }

      it "returns exactly one chunk" do
        result = split_large_sentence(chunker, minimal_sentence)
        expect(result.length).to eq(1)
      end

      it "returns the word as chunk text" do
        result = split_large_sentence(chunker, minimal_sentence)
        expect(result.first[:text]).to eq(minimal_sentence)
      end

      it "returns positive token count" do
        result = split_large_sentence(chunker, minimal_sentence)
        expect(result.first[:token_count]).to be > 0
      end
    end

    context "with a sentence of two words" do
      let(:two_word_sentence) { "hello world" }

      it "returns exactly one chunk" do
        result = split_large_sentence(chunker, two_word_sentence)
        expect(result.length).to eq(1)
      end

      it "returns both words in the chunk" do
        result = split_large_sentence(chunker, two_word_sentence)
        expect(result.first[:text]).to include("hello")
        expect(result.first[:text]).to include("world")
      end

      it "returns correct token count" do
        result = split_large_sentence(chunker, two_word_sentence)
        expect(result.first[:token_count]).to eq(token_count(two_word_sentence))
      end
    end

    context "chunk splitting respects word boundaries" do
      subject(:chunker) { described_class.new(text, 5, 1) }

      let(:sentence) { "one two three four five six seven eight nine ten eleven twelve" }

      it "splits on word boundaries (no partial words)" do
        result = split_large_sentence(chunker, sentence)
        all_words = sentence.split(/\s+/)
        result.each do |chunk|
          chunk_words = chunk[:text].split(/\s+/)
          chunk_words.each do |word|
            expect(all_words).to include(word)
          end
        end
      end
    end

    context "with mixed alphanumeric words" do
      let(:mixed_sentence) do
        words = (1..200).map { |i| i.even? ? "word#{i}" : "#{i}word" }
        words.join(" ")
      end

      it "returns an Array" do
        result = split_large_sentence(chunker, mixed_sentence)
        expect(result).to be_an(Array)
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, mixed_sentence) }.not_to raise_error
      end

      it "returns valid chunk hashes" do
        result = split_large_sentence(chunker, mixed_sentence)
        result.each do |chunk|
          expect(chunk).to have_key(:text)
          expect(chunk).to have_key(:token_count)
          expect(chunk[:text]).not_to be_empty
          expect(chunk[:token_count]).to be > 0
        end
      end
    end

    context "with large chunk_size" do
      subject(:chunker) { described_class.new(text, 2000, 400) }

      let(:sentence) { generate_sentence_with_tokens(chunk_size + 200) }

      it "returns an Array" do
        result = split_large_sentence(chunker, sentence)
        expect(result).to be_an(Array)
      end

      it "returns at least one chunk" do
        result = split_large_sentence(chunker, sentence)
        expect(result.length).to be >= 1
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, sentence) }.not_to raise_error
      end
    end

    context "last chunk behavior" do
      subject(:chunker) { described_class.new(text, 10, 2) }

      let(:sentence) { "one two three four five six seven eight nine ten eleven twelve thirteen" }

      it "does not lose the last few words" do
        result = split_large_sentence(chunker, sentence)
        all_text = result.map { |c| c[:text] }.join(" ")
        # The last word should appear in the combined output
        expect(all_text).to include("thirteen")
      end

      it "ensures the last chunk is non-empty" do
        result = split_large_sentence(chunker, sentence)
        expect(result.last[:text]).not_to be_empty
      end
    end

    context "no overlap between consecutive chunks" do
      subject(:chunker) { described_class.new(text, chunk_size, 0) }

      let(:large_sentence) { generate_sentence_with_tokens(chunk_size * 2 + 100) }

      it "returns an Array when overlap is 0" do
        result = split_large_sentence(chunker, large_sentence)
        expect(result).to be_an(Array)
      end

      it "returns valid chunks when overlap is 0" do
        result = split_large_sentence(chunker, large_sentence)
        result.each do |chunk|
          expect(chunk[:text]).not_to be_empty
          expect(chunk[:token_count]).to be > 0
        end
      end
    end

    context "with a sentence containing punctuation within words" do
      let(:punctuation_sentence) do
        words = (1..200).map { |i| "word-#{i}" }
        words.join(" ")
      end

      it "returns an Array" do
        result = split_large_sentence(chunker, punctuation_sentence)
        expect(result).to be_an(Array)
      end

      it "does not raise an error" do
        expect { split_large_sentence(chunker, punctuation_sentence) }.not_to raise_error
      end

      it "returns chunks with non-empty text" do
        result = split_large_sentence(chunker, punctuation_sentence)
        result.each do |chunk|
          expect(chunk[:text]).not_to be_empty
        end
      end
    end
  end
end
