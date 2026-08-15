import { postgresAdapter } from '@payloadcms/db-postgres'
import { lexicalEditor } from '@payloadcms/richtext-lexical'
import { en } from '@payloadcms/translations/languages/en'
import { pt } from '@payloadcms/translations/languages/pt'
import path from 'path'
import { buildConfig } from 'payload'
import sharp from 'sharp'
import { fileURLToPath } from 'url'

import { Users } from './collections/Users'

const filename = fileURLToPath(import.meta.url)
const dirname = path.dirname(filename)

// ---------------------------------------------------------------------------
// INVARIANTES TRAVADAS POR CONSTRUÇÃO (não deixar para o LLM):
// - INV-1: admin SEMPRE em pt-BR (fallbackLanguage: 'pt') e MENU COMPLETO —
//   nenhuma collection com `admin.hidden` e nenhum `admin.group` que oculte
//   entradas do menu.
// - INV-3: Postgres como banco (postgresAdapter). Redis (fila) vem da infra
//   compartilhada e é usado pelos jobs/consumidores do projeto.
//
// O LLM do modo /mosk-bench SÓ deve editar `src/collections/` e labels.
// NUNCA reescrever este arquivo base, o compose ou a infra (FR-011).
// ---------------------------------------------------------------------------

export default buildConfig({
  admin: {
    user: Users.slug,
    importMap: {
      baseDir: path.resolve(dirname),
    },
  },
  // Registro de collections (FR-011). Novas collections entram AQUI, sem `hidden`
  // e sem agrupamentos que escondam o menu (INV-1).
  collections: [Users],
  editor: lexicalEditor(),
  secret: process.env.PAYLOAD_SECRET || '',
  typescript: {
    outputFile: path.resolve(dirname, 'payload-types.ts'),
  },
  db: postgresAdapter({
    pool: {
      connectionString: process.env.DATABASE_URI || '',
    },
  }),
  sharp,
  // Admin em português por padrão (INV-1). `en` fica disponível como opção,
  // mas o fallback e a experiência padrão do leigo são pt-BR.
  i18n: {
    fallbackLanguage: 'pt',
    supportedLanguages: { pt, en },
  },
})
