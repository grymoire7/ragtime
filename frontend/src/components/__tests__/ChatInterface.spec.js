import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import ChatInterface from '../ChatInterface.vue';
import { chatsAPI, documentsAPI } from '../../services/api';

// Mock the router
const mockPush = vi.fn();
vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush
  })
}));

// Mock the API
vi.mock('../../services/api', () => ({
  chatsAPI: {
    create: vi.fn(),
    get: vi.fn()
  },
  messagesAPI: {
    create: vi.fn()
  },
  documentsAPI: {
    list: vi.fn()
  }
}));

describe('ChatInterface', () => {
  const mountOptions = {
    global: {
      stubs: {
        'router-link': {
          template: '<a :href="to"><slot /></a>',
          props: ['to']
        }
      }
    }
  };

  beforeEach(() => {
    vi.clearAllMocks();

    // Default mock responses
    chatsAPI.create.mockResolvedValue({ data: { id: 1 } });
    documentsAPI.list.mockResolvedValue({ data: [] });
  });

  describe('component initialization', () => {
    it('mounts successfully', async () => {
      const wrapper = mount(ChatInterface, mountOptions);
      await flushPromises();

      expect(wrapper.exists()).toBe(true);
    });

    it('renders the main chat interface container', async () => {
      const wrapper = mount(ChatInterface, mountOptions);
      await flushPromises();

      const chatInterface = wrapper.find('.chat-interface');
      expect(chatInterface.exists()).toBe(true);
    });
  });

  describe('citation display formatting', () => {
    it('formats citation title with chunk position', () => {
      const wrapper = mount(ChatInterface, mountOptions);

      const citation = {
        document_title: 'Test.pdf',
        position: 2,
        chunk_id: 5,
        document_id: 1,
        relevance: 0.85
      };

      const result = wrapper.vm.formatCitationTitle(citation);
      expect(result).toBe('Test.pdf (Chunk #3)');
    });

    it('formats citation title without position when position is undefined', () => {
      const wrapper = mount(ChatInterface, mountOptions);

      const citation = {
        document_title: 'Test.pdf',
        chunk_id: 5,
        document_id: 1,
        relevance: 0.85
      };

      const result = wrapper.vm.formatCitationTitle(citation);
      expect(result).toBe('Test.pdf');
    });

    it('formats citation title without position when position is null', () => {
      const wrapper = mount(ChatInterface, mountOptions);

      const citation = {
        document_title: 'Test.pdf',
        position: null,
        chunk_id: 5,
        document_id: 1,
        relevance: 0.85
      };

      const result = wrapper.vm.formatCitationTitle(citation);
      expect(result).toBe('Test.pdf');
    });

    it('formats relevance score as percentage', () => {
      const wrapper = mount(ChatInterface, mountOptions);

      const result = wrapper.vm.formatRelevance(0.92);
      expect(result).toBe('92%');
    });

    it('rounds relevance score to nearest integer', () => {
      const wrapper = mount(ChatInterface, mountOptions);

      const result = wrapper.vm.formatRelevance(0.876);
      expect(result).toBe('88%');
    });
  });

  describe('message checks', () => {
    it('returns true when message has citations', () => {
      const wrapper = mount(ChatInterface, mountOptions);

      const message = {
        metadata: {
          citations: [
            { chunk_id: 1, document_id: 1, document_title: 'Doc.pdf' }
          ]
        }
      };

      expect(wrapper.vm.hasCitations(message)).toBe(true);
    });

    it('returns false when message has empty citations array', () => {
      const wrapper = mount(ChatInterface, mountOptions);

      const message = {
        metadata: {
          citations: []
        }
      };

      expect(wrapper.vm.hasCitations(message)).toBe(false);
    });

    it('returns falsy when message has no metadata', () => {
      const wrapper = mount(ChatInterface, mountOptions);

      const message = {};

      expect(wrapper.vm.hasCitations(message)).toBeFalsy();
    });
  });
});
