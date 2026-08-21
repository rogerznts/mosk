## 🧰 MOSK v016 — o toolkit ficou bem menor

Saiu a maior limpeza desde o começo. Resumo do que muda pra vocês.

**O que aconteceu:** a regra do pipeline (fases, transições, gate, promoções) saía espalhada em código Bash. Agora vive num arquivo só — `.claude/mosk/pipeline.yaml` — e quem lê é o agente. Bash ficou só pro que agente não faz: criar spec, gerar arquivo derivado e validar.

**Números:** 7.912 → 2.563 linhas de shell · 25 → 5 scripts · zero self-test

---

### O que muda no dia a dia

**Comandos que sumiram:**
```
doctor.sh              → validate.sh install
check-ship-ready.sh    → validate.sh ship-ready
audit-docs-paths.sh    → validate.sh docs-paths
check-prerequisites.sh → validate.sh prerequisites --for <fase>
                       → validate.sh all   (roda tudo)
```

**Transição de fase deixou de ser comando.** Não existe mais `transition-spec-phase.sh` — o agente aplica seguindo o contrato, lendo o `pipeline.yaml`. Vocês não chamam nada; as tasks fazem.

**Migração de projeto legado virou task:** `migrate-install` (era script). Idem `sync-hallmark`.

**`sync-agents-skills` + `link-codex-skills` viraram `sync.sh`:**
```
bash .claude/mosk/scripts/sync.sh skills   # agentes → wrappers
bash .claude/mosk/scripts/sync.sh codex    # .codex/ + AGENTS.md
bash .claude/mosk/scripts/sync.sh all
```

---

### ⚠️ Novidade que vai te bloquear (de propósito)

Tem um hook novo: **spec não arquivada não deixa abrir PR nem dar merge.**

Se aparecer `Bloqueado: a spec deste branch nao esta fechada`, rode `/mosk-dev archive` e commite. Pra conferir antes: `bash .claude/mosk/scripts/validate.sh ship-ready`.

Ele existe porque uma spec chegou ao master em `qa-gate` sem ninguém notar — o verificador existia, mas nada o chamava.

**Ele precisa ser registrado no `.claude/settings.json` pra funcionar.** O `/mosk-boot` faz isso; em projeto que já tem MOSK, confere se o bloco `PreToolUse` está lá.

---

### Como atualizar

```
/mosk-update
```

Depois: `bash .claude/mosk/scripts/validate.sh all` — tem que sair tudo OK.

Nada que vocês escreveram muda: `.claude/rules/`, `docs/`, specs e settings são preservados.

---

### Duas regras novas de estilo

1. **Código sempre em inglês** — nome de função, variável, arquivo, branch. A conversa é em pt-BR, o artefato não.
2. **Todo id vem com o significado na primeira menção.** `FR-009`, `SC-001`, `ADR-0021` não dizem nada sozinhos. Escreva "o FR-009 — nenhuma regra sai antes do equivalente declarativo — exige X".

---

Detalhes: `README.md` (seção *Where a rule lives*) e `docs/architecture/adr/adr-0021-declarative-rule-minimal-shell.md`.
