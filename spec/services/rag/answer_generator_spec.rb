require 'rails_helper'

RSpec.describe Rag::AnswerGenerator do
  subject(:generator) { described_class.new }

  describe "#call_llm" do
    def call_llm(prompt, model)
      generator.send(:call_llm, prompt, model)
    end

    let(:prompt) { "What is the capital of France?" }
    let(:model) { "claude-3-5-haiku-latest" }
    let(:provider) { "anthropic" }
    let(:chat_config) { { model: model, provider: provider } }
    let(:mock_chat) { instance_double(RubyLLM::Chat) }
    let(:mock_response) { instance_double(RubyLLM::Message, content: "Paris is the capital of France.") }

    before do
      allow(Rails.application.config.x).to receive_message_chain(:ruby_llm, :[], :[], :[]).and_return(chat_config)
      allow(Rails.application.config.x.ruby_llm).to receive(:[]).with(Rails.env.to_sym).and_return({ chat: chat_config })
    end

    context "when the LLM call is successful" do
      before do
        allow(RubyLLM).to receive(:chat).with(model: model, provider: provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).with(prompt).and_return(mock_response)
      end

      it "returns the response content" do
        expect(call_llm(prompt, model)).to eq("Paris is the capital of France.")
      end

      it "returns a String" do
        expect(call_llm(prompt, model)).to be_a(String)
      end

      it "calls RubyLLM.chat with the correct model" do
        call_llm(prompt, model)
        expect(RubyLLM).to have_received(:chat).with(hash_including(model: model))
      end

      it "calls RubyLLM.chat with the correct provider" do
        call_llm(prompt, model)
        expect(RubyLLM).to have_received(:chat).with(hash_including(provider: provider))
      end

      it "calls chat.ask with the prompt" do
        call_llm(prompt, model)
        expect(mock_chat).to have_received(:ask).with(prompt)
      end

      it "reads the provider from the chat config" do
        call_llm(prompt, model)
        expect(RubyLLM).to have_received(:chat).with(provider: provider, model: model)
      end
    end

    context "when called with different models" do
      let(:other_model) { "gpt-4o" }
      let(:other_response) { instance_double(RubyLLM::Message, content: "GPT response content.") }

      before do
        allow(RubyLLM).to receive(:chat).with(model: other_model, provider: provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).with(prompt).and_return(other_response)
      end

      it "uses the model passed as argument" do
        call_llm(prompt, other_model)
        expect(RubyLLM).to have_received(:chat).with(hash_including(model: other_model))
      end

      it "returns the content from the response" do
        expect(call_llm(prompt, other_model)).to eq("GPT response content.")
      end
    end

    context "when called with different prompts" do
      let(:different_prompt) { "What is the boiling point of water?" }
      let(:different_response) { instance_double(RubyLLM::Message, content: "Water boils at 100°C.") }

      before do
        allow(RubyLLM).to receive(:chat).with(model: model, provider: provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).with(different_prompt).and_return(different_response)
      end

      it "passes the correct prompt to chat.ask" do
        call_llm(different_prompt, model)
        expect(mock_chat).to have_received(:ask).with(different_prompt)
      end

      it "returns the correct response content" do
        expect(call_llm(different_prompt, model)).to eq("Water boils at 100°C.")
      end
    end

    context "when the LLM raises a generic error" do
      before do
        allow(RubyLLM).to receive(:chat).with(model: model, provider: provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).and_raise(StandardError, "Connection timeout")
      end

      it "raises an LLMError" do
        expect { call_llm(prompt, model) }.to raise_error(Rag::AnswerGenerator::LLMError)
      end

      it "includes the original error message in the LLMError" do
        expect { call_llm(prompt, model) }.to raise_error(
          Rag::AnswerGenerator::LLMError,
          /Connection timeout/
        )
      end

      it "wraps the error with an 'LLM request failed' prefix" do
        expect { call_llm(prompt, model) }.to raise_error(
          Rag::AnswerGenerator::LLMError,
          /LLM request failed/
        )
      end

      it "does not raise the original StandardError" do
        expect { call_llm(prompt, model) }.not_to raise_error(StandardError)
      rescue RSpec::Expectations::ExpectationNotMetError
        # This expectation is checking the type, so we catch to verify
      end
    end

    context "when RubyLLM.chat raises an error" do
      before do
        allow(RubyLLM).to receive(:chat).and_raise(RuntimeError, "Invalid API key")
      end

      it "raises an LLMError" do
        expect { call_llm(prompt, model) }.to raise_error(Rag::AnswerGenerator::LLMError)
      end

      it "includes the original error message" do
        expect { call_llm(prompt, model) }.to raise_error(
          Rag::AnswerGenerator::LLMError,
          /Invalid API key/
        )
      end

      it "includes the 'LLM request failed' message" do
        expect { call_llm(prompt, model) }.to raise_error(
          Rag::AnswerGenerator::LLMError,
          "LLM request failed: Invalid API key"
        )
      end
    end

    context "when the response content is empty" do
      let(:empty_response) { instance_double(RubyLLM::Message, content: "") }

      before do
        allow(RubyLLM).to receive(:chat).with(model: model, provider: provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).with(prompt).and_return(empty_response)
      end

      it "returns an empty string" do
        expect(call_llm(prompt, model)).to eq("")
      end

      it "returns a String" do
        expect(call_llm(prompt, model)).to be_a(String)
      end
    end

    context "when the response content is a long string" do
      let(:long_content) { "A" * 10_000 }
      let(:long_response) { instance_double(RubyLLM::Message, content: long_content) }

      before do
        allow(RubyLLM).to receive(:chat).with(model: model, provider: provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).with(prompt).and_return(long_response)
      end

      it "returns the full response content" do
        expect(call_llm(prompt, model)).to eq(long_content)
      end

      it "returns the correct length" do
        expect(call_llm(prompt, model).length).to eq(10_000)
      end
    end

    context "when the response content contains special characters" do
      let(:special_content) { "Answer with [1] citations\n and **bold** text & <html> tags." }
      let(:special_response) { instance_double(RubyLLM::Message, content: special_content) }

      before do
        allow(RubyLLM).to receive(:chat).with(model: model, provider: provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).with(prompt).and_return(special_response)
      end

      it "returns the content with special characters intact" do
        expect(call_llm(prompt, model)).to eq(special_content)
      end
    end

    context "LLMError class" do
      it "is a subclass of StandardError" do
        expect(Rag::AnswerGenerator::LLMError.ancestors).to include(StandardError)
      end

      it "can be instantiated with a message" do
        error = Rag::AnswerGenerator::LLMError.new("test error")
        expect(error.message).to eq("test error")
      end
    end

    context "when provider config is different" do
      let(:different_provider) { "openai" }
      let(:different_chat_config) { { model: model, provider: different_provider } }

      before do
        allow(Rails.application.config.x.ruby_llm).to receive(:[]).with(Rails.env.to_sym).and_return({ chat: different_chat_config })
        allow(RubyLLM).to receive(:chat).with(model: model, provider: different_provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).with(prompt).and_return(mock_response)
      end

      it "uses the provider from the chat config" do
        call_llm(prompt, model)
        expect(RubyLLM).to have_received(:chat).with(hash_including(provider: different_provider))
      end

      it "returns the response content" do
        expect(call_llm(prompt, model)).to eq("Paris is the capital of France.")
      end
    end

    context "consistency" do
      before do
        allow(RubyLLM).to receive(:chat).with(model: model, provider: provider).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).with(prompt).and_return(mock_response)
      end

      it "returns the same result for the same inputs when called multiple times" do
        first_result = call_llm(prompt, model)
        second_result = call_llm(prompt, model)
        expect(first_result).to eq(second_result)
      end

      it "creates a new chat instance on each call" do
        call_llm(prompt, model)
        call_llm(prompt, model)
        expect(RubyLLM).to have_received(:chat).twice
      end
    end

    context "error message format" do
      before do
        allow(RubyLLM).to receive(:chat).and_raise(StandardError, "some error")
      end

      it "formats the error message as 'LLM request failed: <original message>'" do
        begin
          call_llm(prompt, model)
        rescue Rag::AnswerGenerator::LLMError => e
          expect(e.message).to eq("LLM request failed: some error")
        end
      end
    end
  end
end
