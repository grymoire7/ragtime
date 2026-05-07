require 'rails_helper'

RSpec.describe ChatResponseJob, type: :job do
  describe '#perform' do
    let(:chat) { instance_double(Chat) }
    let(:messages_association) { instance_double(ActiveRecord::Associations::CollectionProxy) }
    let(:chat_id) { 42 }
    let(:content) { 'What is the meaning of life?' }
    let(:options) { {} }

    let(:rag_result) do
      {
        answer: 'The meaning of life is 42.',
        citations: [{ document_id: 1, title: 'Hitchhiker\'s Guide', excerpt: 'Deep Thought said so.' }],
        empty_context: nil
      }
    end

    let(:user_message) { instance_double(Message, id: 1, role: 'user', content: content) }
    let(:assistant_message) do
      instance_double(
        Message,
        id: 2,
        role: 'assistant',
        content: rag_result[:answer],
        metadata: { citations: rag_result[:citations] }
      )
    end

    before do
      allow(Chat).to receive(:find).with(chat_id).and_return(chat)
      allow(chat).to receive(:messages).and_return(messages_association)
    end

    context 'when the chat exists and RAG generates a successful response' do
      before do
        allow(Rag::AnswerGenerator).to receive(:generate).with(content, options).and_return(rag_result)
        allow(messages_association).to receive(:create!).and_return(user_message, assistant_message)
      end

      it 'finds the chat by id' do
        described_class.perform_now(chat_id, content, options)
        expect(Chat).to have_received(:find).with(chat_id)
      end

      it 'calls Rag::AnswerGenerator with the content and options' do
        described_class.perform_now(chat_id, content, options)
        expect(Rag::AnswerGenerator).to have_received(:generate).with(content, options)
      end

      it 'creates the user message with correct attributes' do
        described_class.perform_now(chat_id, content, options)
        expect(messages_association).to have_received(:create!).with(
          role: 'user',
          content: content
        )
      end

      it 'creates the assistant message with citations in metadata' do
        described_class.perform_now(chat_id, content, options)
        expect(messages_association).to have_received(:create!).with(
          role: 'assistant',
          content: rag_result[:answer],
          metadata: { citations: rag_result[:citations] }
        )
      end

      it 'creates the user message before the assistant message' do
        call_order = []
        allow(messages_association).to receive(:create!) do |attrs|
          call_order << attrs[:role]
          attrs[:role] == 'user' ? user_message : assistant_message
        end

        described_class.perform_now(chat_id, content, options)
        expect(call_order).to eq(%w[user assistant])
      end

      context 'when empty_context is present in the RAG result' do
        let(:rag_result) do
          {
            answer: 'I could not find relevant information.',
            citations: [],
            empty_context: true
          }
        end

        it 'includes empty_context in the assistant message metadata' do
          described_class.perform_now(chat_id, content, options)
          expect(messages_association).to have_received(:create!).with(
            role: 'assistant',
            content: rag_result[:answer],
            metadata: { citations: [], empty_context: true }
          )
        end
      end

      context 'when empty_context is nil in the RAG result' do
        let(:rag_result) do
          {
            answer: 'The meaning of life is 42.',
            citations: [{ document_id: 1 }],
            empty_context: nil
          }
        end

        it 'does not include empty_context in the assistant message metadata' do
          described_class.perform_now(chat_id, content, options)
          expect(messages_association).to have_received(:create!).with(
            role: 'assistant',
            content: rag_result[:answer],
            metadata: { citations: rag_result[:citations] }
          )
        end
      end

      context 'when empty_context is false in the RAG result' do
        let(:rag_result) do
          {
            answer: 'The meaning of life is 42.',
            citations: [{ document_id: 1 }],
            empty_context: false
          }
        end

        it 'does not include empty_context in the assistant message metadata' do
          described_class.perform_now(chat_id, content, options)
          expect(messages_association).to have_received(:create!).with(
            role: 'assistant',
            content: rag_result[:answer],
            metadata: { citations: rag_result[:citations] }
          )
        end
      end

      context 'when options include a created_after filter' do
        let(:options) { { created_after: '2024-01-01' } }

        it 'passes options through to the RAG answer generator' do
          described_class.perform_now(chat_id, content, options)
          expect(Rag::AnswerGenerator).to have_received(:generate).with(content, options)
        end
      end

      context 'when no options are provided' do
        it 'uses an empty hash as default options' do
          described_class.perform_now(chat_id, content)
          expect(Rag::AnswerGenerator).to have_received(:generate).with(content, {})
        end
      end
    end

    context 'when the chat does not exist' do
      before do
        allow(Chat).to receive(:find).with(chat_id).and_raise(ActiveRecord::RecordNotFound)
      end

      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_now(chat_id, content, options)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'does not call Rag::AnswerGenerator' do
        allow(Rag::AnswerGenerator).to receive(:generate)
        begin
          described_class.perform_now(chat_id, content, options)
        rescue ActiveRecord::RecordNotFound
          # expected
        end
        expect(Rag::AnswerGenerator).not_to have_received(:generate)
      end
    end

    context 'when Rag::AnswerGenerator raises an error' do
      before do
        allow(Rag::AnswerGenerator).to receive(:generate).and_raise(StandardError, 'RAG service unavailable')
      end

      it 'raises the error' do
        expect {
          described_class.perform_now(chat_id, content, options)
        }.to raise_error(StandardError, 'RAG service unavailable')
      end

      it 'does not create any messages' do
        allow(messages_association).to receive(:create!)
        begin
          described_class.perform_now(chat_id, content, options)
        rescue StandardError
          # expected
        end
        expect(messages_association).not_to have_received(:create!)
      end
    end

    context 'when creating the user message fails' do
      before do
        allow(Rag::AnswerGenerator).to receive(:generate).with(content, options).and_return(rag_result)
        allow(messages_association).to receive(:create!).with(role: 'user', content: content)
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it 'raises ActiveRecord::RecordInvalid' do
        expect {
          described_class.perform_now(chat_id, content, options)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'does not attempt to create the assistant message' do
        allow(messages_association).to receive(:create!).with(hash_including(role: 'assistant'))
        begin
          described_class.perform_now(chat_id, content, options)
        rescue ActiveRecord::RecordInvalid
          # expected
        end
        expect(messages_association).not_to have_received(:create!).with(hash_including(role: 'assistant'))
      end
    end

    context 'when creating the assistant message fails' do
      before do
        allow(Rag::AnswerGenerator).to receive(:generate).with(content, options).and_return(rag_result)
        allow(messages_association).to receive(:create!).with(role: 'user', content: content)
          .and_return(user_message)
        allow(messages_association).to receive(:create!).with(hash_including(role: 'assistant'))
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it 'raises ActiveRecord::RecordInvalid' do
        expect {
          described_class.perform_now(chat_id, content, options)
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
