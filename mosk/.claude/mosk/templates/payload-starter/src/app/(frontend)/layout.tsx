import React from 'react'

export const metadata = {
  title: 'Ferramenta interna',
  description: 'Criada com o modo MOSK /mosk-bench.',
}

export default function FrontendLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body
        style={{
          fontFamily: 'system-ui, -apple-system, sans-serif',
          margin: 0,
          minHeight: '100vh',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: '#0f172a',
          color: '#e2e8f0',
        }}
      >
        {children}
      </body>
    </html>
  )
}
