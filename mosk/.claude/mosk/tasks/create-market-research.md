docOutputLocation: docs/discovery/market-research.md
template: `.claude/mosk/templates/market-research-tmpl.yaml`

---

# create-market-research

Produza uma pesquisa de mercado com sizing, segmentos, tendências e implicações
estratégicas.

## Processo

1. Leia o template e execute `.claude/mosk/tasks/create-doc.md` com as fontes e
   o contexto disponíveis.
2. Gere diretamente quando objetivo, mercado e recorte estiverem claros. Se
   uma lacuna material permanecer, faça uma única rodada agrupada.
3. Salve em `docs/discovery/market-research.md`, preservando blocos
   `<!-- custom -->`.

Elicitação avançada e ações de sizing, segmentação ou stress-test do template
são opt-in. Nunca use a flag do template como pausa automática.

## Evidência e destino

- Cite fontes e datas; separe dados observados de estimates e assumptions.
- Mostre a conta de TAM/SAM/SOM, não apenas o resultado.
- Se ligado a uma spec ativa, escreva em `docs/specs/{id}/discovery/` com
  `promote: copy` para `docs/discovery/market-research.md`.
- Ao concluir, conecte achados relevantes ao brief existente e sugira análise
  competitiva apenas quando ela for o próximo recorte útil.
