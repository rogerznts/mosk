import React from 'react'

// Página inicial simples só para o `/` não dar 404. O admin fica em `/admin`.
export default function HomePage() {
  return (
    <main style={{ textAlign: 'center', padding: '2rem', maxWidth: 520 }}>
      <h1 style={{ fontSize: '1.6rem', marginBottom: '0.5rem' }}>Sua ferramenta está no ar 🎉</h1>
      <p style={{ opacity: 0.8, lineHeight: 1.6 }}>
        Acesse o painel de administração para começar a usar.
      </p>
      <p>
        <a
          href="/admin"
          style={{
            display: 'inline-block',
            marginTop: '1rem',
            padding: '0.7rem 1.4rem',
            borderRadius: 8,
            background: '#6366f1',
            color: '#fff',
            textDecoration: 'none',
            fontWeight: 600,
          }}
        >
          Abrir o painel
        </a>
      </p>
    </main>
  )
}
