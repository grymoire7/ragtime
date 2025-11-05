import { createRouter, createWebHistory } from 'vue-router';
import ChatView from '../views/ChatView.vue';
import DocumentDetailView from '../views/DocumentDetailView.vue';
import LoginView from '../views/LoginView.vue';
import { useAuth } from '../composables/useAuth';

const routes = [
  {
    path: '/login',
    name: 'login',
    component: LoginView,
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    name: 'home',
    component: ChatView,
    meta: { requiresAuth: true }
  },
  {
    path: '/documents/:id',
    name: 'document-detail',
    component: DocumentDetailView,
    props: true,
    meta: { requiresAuth: true }
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

// Navigation guard to check authentication before each route
router.beforeEach(async (to, from, next) => {
  const { isAuthenticated, isChecking, checkAuth } = useAuth();

  // If we haven't checked auth status yet, check it now
  if (isChecking.value) {
    await checkAuth();
  }

  const requiresAuth = to.meta.requiresAuth !== false;

  if (requiresAuth && !isAuthenticated.value) {
    // Redirect to login if trying to access protected route while not authenticated
    next({ name: 'login' });
  } else if (to.name === 'login' && isAuthenticated.value) {
    // Redirect to home if trying to access login while already authenticated
    next({ name: 'home' });
  } else {
    next();
  }
});

export default router;
