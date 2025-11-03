import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { nextTick } from 'vue';
import DocumentDetailView from '../DocumentDetailView.vue';
import { documentsAPI } from '../../services/api';
import * as vueRouter from 'vue-router';

// Mock vue-router
vi.mock('vue-router', async () => {
  const actual = await vi.importActual('vue-router');
  return {
    ...actual,
    useRoute: vi.fn(),
    useRouter: vi.fn()
  };
});

// Mock the API
vi.mock('../../services/api', () => ({
  documentsAPI: {
    get: vi.fn()
  }
}));

describe('DocumentDetailView', () => {
  const mockDocument = {
    id: 1,
    title: 'Test Document',
    filename: 'test.pdf',
    content_type: 'application/pdf',
    file_size: 1024,
    status: 'completed',
    created_at: '2025-01-01T00:00:00Z',
    chunks: [
      { id: 1, position: 0, content: 'First chunk content', token_count: 100 },
      { id: 2, position: 1, content: 'Second chunk content', token_count: 150 },
      { id: 3, position: 2, content: 'Third chunk content', token_count: 120 }
    ]
  };

  beforeEach(() => {
    vi.clearAllMocks();

    // Default mock router setup
    vueRouter.useRouter.mockReturnValue({
      push: vi.fn()
    });

    // Default route - can be overridden in specific tests
    vueRouter.useRoute.mockReturnValue({
      params: { id: '1' },
      query: {}
    });
  });

  describe('chunk highlighting', () => {
    it('highlights the chunk with matching ID when highlight query param is present', async () => {
      // Override route with highlight parameter
      vueRouter.useRoute.mockReturnValue({
        params: { id: '1' },
        query: { highlight: '2' }
      });

      documentsAPI.get.mockResolvedValue({ data: mockDocument });

      const wrapper = mount(DocumentDetailView);
      await flushPromises();
      await nextTick();

      // Find the highlighted chunk
      const chunks = wrapper.findAll('.chunk-card');
      const highlightedChunk = chunks.find(chunk => chunk.classes('highlighted'));

      expect(highlightedChunk).toBeDefined();
      expect(highlightedChunk.attributes('id')).toBe('chunk-2');
    });

    it('does not highlight any chunk when no highlight query param', async () => {
      documentsAPI.get.mockResolvedValue({ data: mockDocument });

      const wrapper = mount(DocumentDetailView);
      await flushPromises();

      const highlightedChunks = wrapper.findAll('.chunk-card.highlighted');
      expect(highlightedChunks.length).toBe(0);
    });
  });

  describe('visible chunks filtering', () => {
    it('shows only the cited chunk by default when highlight is present', async () => {
      // Override route with highlight parameter
      vueRouter.useRoute.mockReturnValue({
        params: { id: '1' },
        query: { highlight: '2' }
      });

      documentsAPI.get.mockResolvedValue({ data: mockDocument });

      const wrapper = mount(DocumentDetailView);
      await flushPromises();

      const chunks = wrapper.findAll('.chunk-card');
      expect(chunks.length).toBe(1);
      expect(chunks[0].attributes('id')).toBe('chunk-2');
    });

    it('shows all chunks when no highlight is present', async () => {
      documentsAPI.get.mockResolvedValue({ data: mockDocument });

      const wrapper = mount(DocumentDetailView);
      await flushPromises();

      const chunks = wrapper.findAll('.chunk-card');
      expect(chunks.length).toBe(3);
    });

    it('shows all chunks when "Show all context" is toggled', async () => {
      // Override route with highlight parameter
      vueRouter.useRoute.mockReturnValue({
        params: { id: '1' },
        query: { highlight: '2' }
      });

      documentsAPI.get.mockResolvedValue({ data: mockDocument });

      const wrapper = mount(DocumentDetailView);
      await flushPromises();

      // Initially only cited chunk shown
      let chunks = wrapper.findAll('.chunk-card');
      expect(chunks.length).toBe(1);

      // Click "Show all context" toggle
      const toggleLink = wrapper.find('.toggle-link');
      await toggleLink.trigger('click');
      await nextTick();

      // Now all chunks shown
      chunks = wrapper.findAll('.chunk-card');
      expect(chunks.length).toBe(3);
    });
  });

  describe('chunk labeling', () => {
    it('displays chunk position starting from 1', async () => {
      documentsAPI.get.mockResolvedValue({ data: mockDocument });

      const wrapper = mount(DocumentDetailView);
      await flushPromises();

      const chunkLabels = wrapper.findAll('.chunk-label');
      expect(chunkLabels[0].text()).toContain('Chunk #1');
      expect(chunkLabels[1].text()).toContain('Chunk #2');
      expect(chunkLabels[2].text()).toContain('Chunk #3');
    });

    it('shows CITED badge on highlighted chunk', async () => {
      // Override route with highlight parameter
      vueRouter.useRoute.mockReturnValue({
        params: { id: '1' },
        query: { highlight: '2' }
      });

      documentsAPI.get.mockResolvedValue({ data: mockDocument });

      const wrapper = mount(DocumentDetailView);
      await flushPromises();

      const citedBadge = wrapper.find('.cited-badge');
      expect(citedBadge.exists()).toBe(true);
      expect(citedBadge.text()).toBe('CITED');
    });
  });

  describe('context chunk styling', () => {
    it('applies context-chunk class to non-cited chunks when showing all', async () => {
      // Override route with highlight parameter
      vueRouter.useRoute.mockReturnValue({
        params: { id: '1' },
        query: { highlight: '2' }
      });

      documentsAPI.get.mockResolvedValue({ data: mockDocument });

      const wrapper = mount(DocumentDetailView);
      await flushPromises();

      // Toggle to show all chunks
      const toggleLink = wrapper.find('.toggle-link');
      await toggleLink.trigger('click');
      await nextTick();

      const chunks = wrapper.findAll('.chunk-card');

      // Chunk with id=2 should be highlighted, not context
      expect(chunks.find(c => c.attributes('id') === 'chunk-2').classes('highlighted')).toBe(true);
      expect(chunks.find(c => c.attributes('id') === 'chunk-2').classes('context-chunk')).toBe(false);

      // Other chunks should be context chunks
      expect(chunks.find(c => c.attributes('id') === 'chunk-1').classes('context-chunk')).toBe(true);
      expect(chunks.find(c => c.attributes('id') === 'chunk-3').classes('context-chunk')).toBe(true);
    });
  });

  describe('error handling', () => {
    it('displays error message when document fails to load', async () => {
      documentsAPI.get.mockRejectedValue(new Error('Network error'));

      const wrapper = mount(DocumentDetailView);
      await flushPromises();

      const errorMessage = wrapper.find('.error-message');
      expect(errorMessage.exists()).toBe(true);
      expect(errorMessage.text()).toContain('Failed to load document');
    });
  });

  describe('loading state', () => {
    it('shows loading spinner while fetching document', async () => {
      let resolvePromise;
      const promise = new Promise(resolve => {
        resolvePromise = resolve;
      });
      documentsAPI.get.mockReturnValue(promise);

      const wrapper = mount(DocumentDetailView);
      await nextTick();

      // Should show loading state
      expect(wrapper.find('.loading-state').exists()).toBe(true);
      expect(wrapper.find('.spinner').exists()).toBe(true);

      // Resolve and wait
      resolvePromise({ data: mockDocument });
      await flushPromises();

      // Should no longer show loading
      expect(wrapper.find('.loading-state').exists()).toBe(false);
    });
  });
});
