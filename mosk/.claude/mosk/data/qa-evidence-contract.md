# Contrato de evidência de QA

Fonte única para `assess-risk`, `assess-nfr`, `design-tests`, `trace-spec` e
`qa-gate`. As tasks especializadas produzem evidência; somente `qa-gate` emite
o veredito do pipeline.

## Evidência mínima

Cada conclusão deve registrar:

- `source`: artefato, comando ou comportamento observado;
- `claim`: afirmação verificável sustentada pela fonte;
- `criterion`: requisito ou AC com sua glossa na primeira menção;
- `status`: `PASS`, `CONCERNS` ou `FAIL`;
- `gap`: diferença concreta entre observado e esperado, quando houver;
- `action`: menor correção verificável, quando houver gap.

Não use ausência de evidência como prova de sucesso. Um item aplicável sem fonte
é `CONCERNS`; quando impede verificar um requisito obrigatório, é `FAIL`.

## Achados

Achados seguem `.claude/mosk/data/output-contract.md`: ids estáveis, título que
se sustenta sozinho, severidade `low|medium|high`, evidência concreta e critério
com significado. Relatórios humanos usam blocos, não tabelas comprimidas.

## Saídas distintas

- `assess-risk`: riscos, probabilidade, impacto, mitigação e gatilho de revisão.
- `assess-nfr`: estado de cada NFR aplicável e fonte observada.
- `design-tests`: cenários priorizados, nível e vínculo com AC/risco.
- `trace-spec`: cobertura AC/requisito → teste/evidência e gaps.
- `qa-gate`: veredito independente, score, histórico e achados acionáveis.

Uma task especializada pode ser pulada quando não agrega evidência distinta. O
gate registra a ausência quando aquela evidência era necessária ao risco do
trabalho.

## Score e decisão

O score é calculado, nunca estimado:

```text
quality_score = 100 - (20 × FAILs) - (10 × CONCERNS)
```

Limite o resultado a `0..100`. Preferências técnicas podem substituir os pesos,
mas devem ser citadas. O score mostra trajetória; não substitui o veredito.

## Persistência

- Gate da spec: `docs/specs/{id}/gate.yaml`.
- Gate de story: `{qa.qaLocation}/gates/{story-id}-{slug}.yml`.
- Avaliações: `{qa.qaLocation}/assessments/` com o identificador avaliado e data.
- Evidência da spec: `qa-notes.md` ou outro path relativo aceito pelo schema.

QA é dono dos gates. Dev corrige a implementação, mas não edita o veredito.
