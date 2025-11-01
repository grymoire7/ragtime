import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      // Proxy API requests to Rails backend
      '/documents': 'http://localhost:3000',
      '/chats': 'http://localhost:3000',
      '/messages': 'http://localhost:3000',
      '/models': 'http://localhost:3000'
    }
  }
})
