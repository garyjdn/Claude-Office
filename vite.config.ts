import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  // Packaged Electron loads dist/index.html via file://, where absolute
  // paths like /assets/*.js resolve to the drive root — use relative paths
  base: './',
  build: {
    // src/config.ts uses top-level await — es2020 (the default) rejects it
    target: 'es2022',
  },
  server: {
    port: 3333,
    proxy: {
      '/ws': {
        target: 'ws://localhost:3334',
        ws: true,
      },
    },
  },
})
