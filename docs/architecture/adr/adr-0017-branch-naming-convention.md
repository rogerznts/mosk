# ADR-0017 — Convenção de nome de branch: `{tipo}/{NNN}-{nome}`

- Status: aceito
- Data: 2026-08-05
- Autor: Vinicius (mosk-architect)
- Contexto: os repositórios reais acumularam pelo menos cinco padrões de nome de branch convivendo; o MOSK gera um sexto.
- Depende de: [adr-0006](./adr-0006-consultative-orchestration-graph.md) (spec-meta como metadado autoritativo), [adr-0010](./adr-0010-orca-backend.md) §6 (base branch por commit).

## Contexto

Amostra real de um repositório em uso, todos convivendo:

```text
feature/061-tax-reform-cbs-ibs      tipo/NNN-nome
059-feature-mcp-reports-fechamento  NNN-tipo-nome   ← o que o MOSK gera
057-hotfix-mcp-tokens-acesso        NNN-tipo-nome
hotfix/bank-gateway-contract-guard  tipo/nome       ← sem número
feat/komodo-deploy-hml              abreviação      ← `feat` em vez de `feature`
chore/sync-042-pmo-into-hml         número no meio
feature/containerizacao             sem número
```

O custo não é estético. Sem padrão único: a listagem do Git não agrupa nem
ordena de forma previsível; não há como saber por inspeção se um branch tem spec
associada; e qualquer automação que resolva "branch → spec" precisa adivinhar
entre formatos — inclusive a do próprio MOSK, que hoje assume igualdade entre
nome de branch e nome de pasta.

A spec 010 já cobrou esse preço: um branch auxiliar chamado
`docs/adr-0012-0014-graph-loop-orca` foi lido como "spec 014" e desviou a
numeração, porque a extração não era ancorada. Corrigir a âncora resolveu o
sintoma; a causa é não haver formato declarado.

## Decisão

**1. Formato canônico: `{tipo}/{NNN}-{nome-kebab}`.**

```text
feature/061-tax-reform-cbs-ibs
fix/062-payment-timeout
hotfix/063-token-expiry
```

O tipo vem primeiro porque é o que a UI do Git usa para agrupar, e é o padrão já
dominante nos repositórios em uso — a convenção segue a prática, não o contrário.

**2. Tipos por extenso, sem abreviação.** `feature` · `fix` · `hotfix` · `gmud`
· `refactor` · `experimental` · `extension` — os mesmos que o
`create-new-feature.sh` já aceita. `feat`, `bug`, `hf` e afins são **rejeitados**:
dois nomes para o mesmo tipo reintroduzem o problema que a convenção resolve.

**3. Trabalho fora de spec usa `{tipo}/{nome}`, sem número.** `chore/`, `docs/`,
`ci/`, `build/`. Número é o que marca "isto tem spec"; usá-lo fora disso torna a
marca inútil. Assim, `chore/sync-042-pmo-into-hml` continua válido — o `042` ali
é parte do nome, não prefixo de spec, e a ausência de `NNN-` logo após a barra é
o que distingue os dois casos sem ambiguidade.

**4. A pasta da spec continua plana: `docs/specs/{NNN}-{tipo}-{nome}/`.**
Branch e pasta **deixam de ter o mesmo nome** — deliberadamente:

- barra em nome de diretório criaria hierarquia acidental (`docs/specs/feature/061-…`);
- o prefixo numérico na pasta mantém a ordenação natural na listagem;
- o vínculo já existe e é explícito: `spec-meta.yaml` tem o campo `branch`.

O acoplamento por igualdade de string sempre foi frágil. O `spec-meta.yaml` passa
a ser a **única** ponte entre os dois.

**5. Resolução `branch → spec` por número, não por igualdade.** Extrair `NNN` de
`{tipo}/{NNN}-…` e localizar a pasta por prefixo numérico (`find_feature_dir_by_number`,
que já existe e já faz isso). Formato legado `{NNN}-{tipo}-{nome}` continua
resolvendo — ele ainda é o que está em uso nas specs criadas até aqui.

**6. Detecção de número reconhece os dois formatos.** O cálculo do próximo número
passa a aceitar `^([a-z]+/)?([0-9]{3})-` — ancorado, com o segmento de tipo
opcional. Sem isso, mudar o formato reintroduziria em uma tacada o bug que a
spec 010 acabou de corrigir: branches novos deixariam de contar, e a numeração
recomeçaria por cima de specs existentes.

**7. Validação na criação, não depois.** `create-new-feature.sh` passa a gerar o
formato canônico e a recusar entrada que não caiba nele — tipo desconhecido,
abreviação, nome não-kebab. Falhar na criação é barato; descobrir no merge, não.

**8. Branches existentes ficam.** Nada é renomeado: renomear branch com PR aberto
quebra referência, e o histórico não ganha nada com isso. A convenção vale para o
que for criado a partir daqui.

## Alternativas consideradas

1. **Manter `{NNN}-{tipo}-{nome}` (o que o MOSK já gera).** Zero mudança de
   script, ordenação por número na listagem plana. Rejeitada: contraria o padrão
   dominante nos repositórios reais, e a ordenação por número é justamente o que a
   **pasta** preserva — o branch não precisa fazer o mesmo trabalho.
2. **`{tipo}/{nome}` sem número.** Mais limpo de ler. Rejeitada: perde-se a
   ligação direta branch ↔ spec, que é o que permite resolver a spec ativa a
   partir do branch corrente sem consultar arquivo nenhum.
3. **Renomear os branches existentes para o padrão novo.** Consistência imediata.
   Rejeitada: quebra PRs abertos e referências em CI, com ganho apenas cosmético.
4. **Fazer a pasta seguir o branch (`docs/specs/feature/061-…`).** Coerência de
   nome. Rejeitada: cria hierarquia acidental por tipo, quebra o glob `specs/*/`
   usado em toda parte, e perde a ordenação numérica.
5. **Validar por hook de CI em vez de na criação.** Pega também branch criado à
   mão. Rejeitada como *substituto* — o custo de descobrir tarde é alto demais.
   Continua válida como camada extra, sobre a validação na criação.

## Consequências

**Positivas:**

- Um formato só para branch de spec, agrupado por tipo na UI do Git.
- Branch com número passa a significar, sem ambiguidade, "tem spec".
- Pasta e branch ficam desacoplados, com `spec-meta.yaml` como ponte explícita —
  mais honesto que a igualdade de string que sempre foi presumida.
- A detecção de número passa a ser declarada, não presumida.

**Negativas / trade-offs:**

- Dois formatos convivendo por tempo indeterminado (legado + canônico). Toda
  resolução precisa aceitar ambos, o que é código a mais em
  `create-new-feature.sh`, `common.sh` e `check-prerequisites.sh`.
- Branch e pasta com nomes diferentes exige atenção de quem procura à mão.
- A validação na criação recusa entradas que hoje passariam — atrito deliberado.

**Risco residual:**

- Mudar o formato mexe exatamente na superfície que a spec 010 consertou. A
  decisão 6 existe para que a correção não seja desfeita, e o
  `selftest-orca-driver.sh` já cobre as duas regras de numeração — a cobertura
  precisa ser estendida ao formato novo junto com a mudança, não depois.
