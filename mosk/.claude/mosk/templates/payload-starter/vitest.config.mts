import tsconfigPaths from 'vite-tsconfig-paths'
import { defineConfig } from 'vitest/config'

// Testes rodam via Local API do Payload (sem HTTP, sem browser) — FR-019.
export default defineConfig({
  plugins: [tsconfigPaths()],
  test: {
    environment: 'node',
    // Payload sobe uma conexão real com Postgres; sem paralelismo entre arquivos
    // para não brigar pela mesma instância/DB.
    fileParallelism: false,
    testTimeout: 60_000,
    hookTimeout: 60_000,
  },
})
