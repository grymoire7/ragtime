import { createRouter, createWebHistory } from 'vue-router';
import ChatView from '../views/ChatView.vue';
import DocumentDetailView from '../views/DocumentDetailView.vue';

const routes = [
  {
    path: '/',
    name: 'home',
    component: ChatView
  },
  {
    path: '/documents/:id',
    name: 'document-detail',
    component: DocumentDetailView,
    props: true
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

export default router;
