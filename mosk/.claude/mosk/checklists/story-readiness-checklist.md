# Checklist canônico de prontidão de story

Fonte única consumida por `enrich-story.md` e `review-story-draft.md`. Avalie
somente evidência presente na story ou em referências acessíveis.

## Identidade e valor

- [ ] Objetivo, usuário e benefício estão explícitos.
- [ ] Vínculo com épico/spec e dependências está claro.
- [ ] Escopo e limites excluem interpretações materialmente diferentes.

## Critérios e comportamento

- [ ] ACs são observáveis, mensuráveis e cobrem o caminho principal.
- [ ] Erros, bordas e compatibilidade aplicáveis estão descritos.
- [ ] Tarefas/subtarefas cobrem cada AC e indicam sequência/dependências.

## Contexto técnico

- [ ] Arquivos, interfaces, modelos e integrações relevantes estão identificados.
- [ ] Decisões vêm de fontes citadas; nenhuma tecnologia ou padrão foi inventado.
- [ ] Restrições de segurança, dados, performance e rollback aplicáveis constam.
- [ ] Referências apontam para seções específicas e explicam sua relevância.

## Testabilidade

- [ ] Estratégia e níveis de teste correspondem ao risco.
- [ ] Cenários críticos, dados/fixtures e comandos conhecidos estão registrados.
- [ ] Lacunas de evidência ou ambiente estão declaradas, não mascaradas.

## Resultado

Emita:

- `READY`: implementação pode começar sem decisão material pendente;
- `NEEDS_REVISION`: gaps são corrigíveis na própria story;
- `BLOCKED`: falta decisão externa de produto, UX ou arquitetura.

Para cada gap, informe severidade, evidência ausente, impacto e correção mínima.
Não use score subjetivo como substituto dos achados.
