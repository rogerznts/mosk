import Redis from 'ioredis'
import { getPayload, type Payload } from 'payload'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'

import config from '../payload.config'

// Smoke via LOCAL API do Payload (sem HTTP, sem browser) — FR-019.
// Roda dentro do container: `docker compose exec app pnpm test`.
// Prova o contrato "sobe e loga" (ADR-0003): admin instancia, login funciona,
// Postgres e Redis conectam.

let payload: Payload

beforeAll(async () => {
  payload = await getPayload({ config })
})

afterAll(async () => {
  // Encerra a conexão do pool para o processo de teste sair limpo.
  await payload?.db?.destroy?.()
})

describe('smoke — a ferramenta sobe e loga', () => {
  it('instancia o Payload com pelo menos uma collection (admin disponível)', () => {
    expect(payload).toBeDefined()
    expect(payload.config.collections.length).toBeGreaterThan(0)
  })

  it('conecta no Postgres e lê a collection Users', async () => {
    const res = await payload.find({ collection: 'users', limit: 1 })
    expect(res).toHaveProperty('docs')
  })

  it('cria um usuário e faz login (auth funciona)', async () => {
    const email = `smoke-${Date.now()}@mosk.dev`
    const password = 'mosk-smoke-123'

    await payload.create({
      collection: 'users',
      data: { email, password, name: 'Smoke' },
    })

    const result = await payload.login({
      collection: 'users',
      data: { email, password },
    })

    expect(result.token).toBeTruthy()
  })

  it('conecta no Redis (ping)', async () => {
    const url = process.env.REDIS_URL || 'redis://redis:6379/0'
    const redis = new Redis(url, { lazyConnect: true, maxRetriesPerRequest: 1 })
    try {
      await redis.connect()
      const pong = await redis.ping()
      expect(pong).toBe('PONG')
    } finally {
      redis.disconnect()
    }
  })
})
