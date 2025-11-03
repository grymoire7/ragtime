<template>
  <div id="app">
    <header class="app-header">
      <div class="header-content">
        <router-link to="/" class="header-link">
          <h1>
            <svg class="logo-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
            </svg>
            Ragtime
          </h1>
          <p class="subtitle">Document Q&A System</p>
        </router-link>
      </div>
    </header>

    <main class="app-main">
      <router-view v-slot="{ Component }">
        <keep-alive>
          <component :is="Component" />
        </keep-alive>
      </router-view>
    </main>

    <footer class="app-footer">
      <p>Built with Rails 8 & Vue 3 • Powered by Anthropic Claude</p>
    </footer>
  </div>
</template>

<script setup>
// Router view handles component loading
</script>

<style>
* {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  background-color: #f7fafc;
  color: #2d3748;
}

#app {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 2rem 0;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.header-content {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 2rem;
}

.header-link {
  text-decoration: none;
  color: inherit;
  display: block;
  transition: opacity 0.2s;
}

.header-link:hover {
  opacity: 0.9;
  cursor: pointer;
}

.header-content h1 {
  margin: 0;
  font-size: 2.5rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  gap: 1rem;
}

.logo-icon {
  width: 48px;
  height: 48px;
  stroke-width: 2;
}

.subtitle {
  margin: 0.5rem 0 0 0;
  font-size: 1.125rem;
  opacity: 0.9;
}

.app-main {
  flex: 1;
}

.app-footer {
  background-color: #2d3748;
  color: #a0aec0;
  padding: 1.5rem 0;
  text-align: center;
}

.app-footer p {
  margin: 0;
  font-size: 0.875rem;
}

/* Scrollbar Styling */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: #f1f1f1;
}

::-webkit-scrollbar-thumb {
  background: #cbd5e0;
  border-radius: 4px;
}

::-webkit-scrollbar-thumb:hover {
  background: #a0aec0;
}
</style>
