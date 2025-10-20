import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Read host/port from environment variables injected at runtime (Vite supports import.meta.env)
const host = process.env.FRONTEND_BIND_HOST || '0.0.0.0'
const port = parseInt(process.env.FRONTEND_BIND_PORT || '5173', 10)

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host,
    port,
  },
  define: {
    // Ensure environment variables are available at build time
    // These will be injected into import.meta.env
    'import.meta.env.VITE_API_URL': JSON.stringify(process.env.VITE_API_URL || 'http://localhost:3001'),
  }
})
