/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      reportsDirectory: './coverage',
      include: [
        'src/lib/**/*.ts',
        'src/components/**/*.{ts,tsx}',
        'src/services/**/*.ts',
      ],
      exclude: [
        'src/main.tsx',
        'src/**/*.d.ts',
        'src/test/**',
        'src/assets/**',
        'src/types/**',
        'src/pages/**',
        'src/hooks/**',
        'src/App.tsx',
        'src/components/layout/**',
        'src/services/admin.ts',
        'src/lib/supabase.ts',
        '**/*.test.{ts,tsx}',
      ],
      thresholds: {
        lines: 80,
      },
    },
  },
})
