import type { CollectionConfig } from 'payload'

// Collection base de autenticação. Garante que o login funciona no PRIMEIRO
// `pnpm dev` (FR-007 do starter / INV-1). Labels em pt-BR.
//
// Sem `admin.hidden` e sem `admin.group` — a entrada aparece no menu completo (INV-1).
export const Users: CollectionConfig = {
  slug: 'users',
  labels: {
    singular: 'Usuário',
    plural: 'Usuários',
  },
  auth: true,
  admin: {
    useAsTitle: 'email',
  },
  fields: [
    {
      name: 'name',
      label: 'Nome',
      type: 'text',
    },
    // O campo `email` e as credenciais são adicionados automaticamente por `auth: true`.
  ],
}
