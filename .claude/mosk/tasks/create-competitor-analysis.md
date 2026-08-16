docOutputLocation: docs/discovery/competitor-analysis.md
template: `.claude/mosk/templates/competitor-analysis-tmpl.yaml`

---

# create-competitor-analysis

Produza uma análise de concorrentes diretos e indiretos, posicionamento,
forças, lacunas e oportunidades de diferenciação.

## Processo

1. Leia o template e execute `.claude/mosk/tasks/create-doc.md` com as fontes e
   o contexto disponíveis.
2. Gere diretamente quando objetivo e recorte competitivo estiverem claros.
   Agrupe em uma única rodada as lacunas que mudem competidores, mercado ou
   decisão estratégica.
3. Salve em `docs/discovery/competitor-analysis.md`, preservando blocos
   `<!-- custom -->`.

War-gaming, cenários de parceria e demais ações do template são elicitação
avançada opt-in; sua mera presença não interrompe o documento.

## Evidência e destino

- Separe fatos públicos de inferências e explicite confiança/limitações.
- Mostre ameaças e lacunas de cada concorrente, com deltas concretos.
- Se ligado a uma spec ativa, escreva em `docs/specs/{id}/discovery/` com
  `promote: copy` para `docs/discovery/competitor-analysis.md`.
- Propague oportunidades relevantes ao brief/PRD existente sem sobrescrever
  conteúdo do usuário.
