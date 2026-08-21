---
promote: docs/architecture/adr/adr-0021-declarative-rule-minimal-shell.md
promote_mode: copy
---

# ADR-0021 — A regra é declarada, não programada: quem lê determina o que o formato pode ser

- Status: aceito
- Data: 2026-08-19
- Autor: Vinicius (mosk-architect)
- Contexto: revisão da premissa que governou as specs 012 a 015, cinco dias depois de o [adr-0018](./adr-0018-remove-orchestration-layer.md) ter removido uma camada pela mesma causa.
- Supersede: ADR-0020 (gramática canônica de YAML, nunca promovido — vive em `specs/015-feature-structured-autonomous-runner/architecture/`).
- Emenda: a Etapa 2 do `../../discovery/toolkit-autonomy-assessment-roadmap.md` (premissa do núcleo determinístico) e, por consequência, as Etapas 3 a 5.
- Preserva intactos: [adr-0012](./adr-0012-route-decision-vs-phase-execution.md), [adr-0015](./adr-0015-agent-as-source-skill-as-wrapper.md), [adr-0016](./adr-0016-agent-invocation-protocol.md), [adr-0019](./adr-0019-autonomous-delivery-runner.md).

## Contexto

O ADR-0018 removeu 2.800 linhas de orquestração em 14/ago/2026. O diagnóstico dele foi correto e a remoção também. **Cinco dias depois, o toolkit tem 14.633 linhas de Bash** — mais que o quíntuplo do que foi removido, em outra camada.

| camada | linhas | |
|---|---:|---|
| Bash | 14.633 | 59% |
| Templates | 5.947 | 24% |
| Tasks (prompts) | 3.611 | 15% |
| Agentes | 1.461 | 6% |

Isso não é reincidência de descuido. É a assinatura de uma **causa que o ADR-0018 não tocou**: ele removeu uma camada, mas não mudou a regra de decisão que faz camadas nascerem em shell. A regra continuou valendo, e produziu a camada seguinte imediatamente.

A regra em vigor veio da Etapa 2 do roadmap de autonomia, e a premissa dela é esta: *regra escrita em prompt não é garantia; logo, regra crítica deve ser codificada em Bash verificável*. A primeira metade é verdadeira. A segunda é um salto — de "prompt não garante" para "shell garante" — e é onde está o erro.

## O fato que decide

O ADR-0020 é o experimento controlado que mede a premissa até o fim.

Ele documenta **treze voltas de correção na mesma família de defeitos**, três emendas ao próprio texto, e uma sequência literal de achados: `QA-3 → QA-7 → QA-10 → QA-14 → QA-17 → SEC-11 → SEC-18 → SEC-19 → SEC-21`. Cada volta fechou o vetor medido; a seguinte apareceu na mesma família, uma linha ao lado. Duas tentativas de quebrar o padrão — fixture antes da correção, oráculo PyYAML — melhoraram algo sem resolver.

E o ponto de chegada é o que decide. Para que o shell pudesse ler aqueles arquivos com segurança, a decisão 6 do ADR-0020 recusa qualquer linha que contenha `"`, `'`, `{`, `[`, `|` ou `>` fora de duas exceções estreitas.

**Nesse ponto o formato deixou de ser YAML.** É um subconjunto proprietário que nenhum parser real exige, que nenhuma ferramenta externa produz por padrão, e cujo custo medido foi reescrever 41 linhas de prosa em 13 arquivos. O toolkit degradou o formato até ele caber no leitor.

Essa é a inversão que este ADR corrige: **a escolha do leitor determinou o que o formato pôde ser.** Não foi o YAML que se mostrou difícil — foi o leitor que era inadequado, e o formato pagou a conta.

O segundo fato, mais curto: a garantia que justificava tudo isso não se aplicou. A spec 014 foi mesclada no `master` em `qa-gate`, sem archive, com o `check-ship-ready.sh` — construído nas specs 012 e 013 para ser a fonte única de "spec fechada" — instalado, correto e nunca invocado. Uma garantia que depende de alguém lembrar de chamá-la tem exatamente a força de uma regra escrita em prompt, com o custo de manutenção de um programa.

O terceiro fato é aritmético. Das 14.633 linhas, **5.374 são `selftest-*.sh`** — existem só para testar os outros scripts — e **2.991** são `common.sh`. Somados, 57% do shell sustenta o próprio shell, e cerca de 7.400 linhas (~50%) não são citadas por nenhum prompt. O custo não é interno: cada uma dessas linhas roda na máquina do consumidor, em bash e zsh, macOS e Linux, com e sem git. Foi essa matriz que gerou os self-tests em dois shells.

## Decisão

**1. A premissa da Etapa 2 é revertida.** Regra crítica do MOSK vive em **dado declarativo lido por prompt**, não em código de shell. A conclusão correta a partir de "prompt não garante" não é "programe em Bash" — é "declare o fato num lugar único e faça a verificação conferir contra ele".

**2. Existe uma fonte única de regra de pipeline: `pipeline.yaml`.** Fases, arestas válidas, pré e pós-condições, artefatos obrigatórios e as exceções nomeadas (como `qa-gate -> implement` restrita a `apply-qa-fixes`) são **dados** nesse arquivo. Nenhuma task repete a regra em prosa; ela referencia o arquivo. Nenhum script a reimplementa.

**3. Script não lê dado estruturado. Recebe por argumento.** Esta é a decisão que fecha a família de defeitos do ADR-0020 por construção, e não por enumeração: onde um script precisar de um valor que mora num YAML, **quem lê o arquivo é o agente** — que tem um parser de verdade — e passa o valor já resolvido na linha de comando. Sem leitor de YAML em shell não há gramática a restringir, não há abridor a enumerar, não há oráculo a manter, e o formato volta a ser YAML inteiro.

**4. A regra de decisão de camada, aplicável sem interpretação.** Para toda regra nova, três perguntas em ordem; a primeira que responder "sim" define a camada:

| # | Pergunta | Camada |
|---|---|---|
| 1 | O fato precisa ser lido por mais de um consumidor, ou sobreviver à sessão? | **YAML** declarativo |
| 2 | É julgamento sobre conteúdo — redigir, avaliar, decidir caso a caso? | **Prompt** (task ou agente) |
| 3 | A aplicação exige algo fora do alcance do agente (lista fechada, abaixo)? | **Script** |

Fora do alcance do agente é uma **lista fechada de três itens**, e ampliá-la exige um ADR:

- **corrida com outro processo no remoto** — reserva de número de spec em `refs/spec-numbers/`;
- **geração determinística de arquivos derivados em massa** — wrappers de skill, symlinks do Codex, reinstalação com remoção de órfãos;
- **execução obrigatória fora da sessão do agente** — hook, CI, branch protection.

Se a regra não cai em nenhum dos três, **não é script**. A ausência de alternativa declarativa precisa ser demonstrada, não presumida.

**5. Garantia sem chamador não conta como garantia.** Toda verificação que o toolkit oferecer precisa declarar quem a invoca, e ter ao menos um ponto de invocação que não dependa de disciplina humana. Uma verificação sem chamador nomeado é dívida, não proteção — é o que a 014 provou.

**6. Prova de comportamento é fixture de contrato, não self-test de shell.** Sem parser em shell e sem regra programada, o que resta a provar é que o dado declarado e o prompt que o lê concordam. Isso se verifica com um punhado de fixtures no verificador único, não com uma suíte que reexecuta shell em duas linguagens.

**7. O ADR-0020 é superseded, não revogado.** A análise dele está certa e o texto se preserva como evidência: ele mediu, com rigor incomum, o custo real de ler dado estruturado em shell. O que cai é a conclusão — restringir a gramática —, porque ela resolve um problema que a decisão 3 elimina. Nenhuma das treze voltas dele teria existido com este ADR em vigor.

## Alternativas consideradas

**Manter a gramática canônica e seguir a 015 até o fim.** Foi a opção default e é a que o roadmap vigente instrui. Rejeitada porque a decisão 6 do ADR-0020 já havia consumido a expressividade do formato para caber no leitor, e o próprio ADR declara que a escolha entre as opções "não é rigor, é quantas voltas futuras cada uma admite". Nenhuma volta é admitida por um leitor que não existe.

**Trocar o parser em shell por uma dependência real (PyYAML, `yq`).** Resolveria a família de defeitos e preservaria o formato. Rejeitada porque reintroduz dependência externa numa instalação por `degit` — o toolkit precisa funcionar sem npm, pip ou PyYAML — e porque não toca a causa: continuaria havendo regra programada, agora com um parser melhor.

**Reduzir o shell sem mudar a regra de decisão.** É o que o ADR-0018 fez, e a medição de cinco dias depois é a resposta. Remover camada sem mudar o critério que a produz é tratar sintoma.

**Confiar a regra inteiramente ao prompt, sem `pipeline.yaml`.** Rejeitada porque a primeira metade da premissa original é verdadeira: regra que só existe em prosa dentro de vários prompts diverge entre eles e não tem fonte única. O dado declarativo é justamente o que dá ao prompt algo contra o que conferir.

## Consequências

**Ganhos.** O formato volta a ser YAML válido, legível por qualquer ferramenta. A superfície de manutenção cai de 14.633 para um alvo de 1.500 linhas de shell. A matriz de compatibilidade que gerou os self-tests (bash × zsh × macOS × Linux × com/sem git) deixa de ser problema do toolkit na maior parte da superfície. A regra do pipeline passa a ser legível por quem mantém sem ler código.

**Custos, declarados.** A verificação passa a depender de o agente ler corretamente um arquivo — o que a premissa original desconfiava. A mitigação não é confiança: é que o fato está num lugar único e verificável, e que a decisão 5 exige chamador nomeado para toda verificação. Um agente que lê errado um `pipeline.yaml` de fonte única é um erro detectável; catorze mil linhas de shell que ninguém invoca não são.

**Trabalho invalidado.** Boa parte do que as specs 012, 013 e 015 produziram em shell sai. Isso é deliberado e é o preço de ter medido a premissa até o fim — o ADR-0020 é o registro dessa medição, e ele custou treze voltas para produzir uma conclusão que agora sabemos ser evitável.

**O que não muda.** Personas, os 12 agentes, agente-como-fonte, protocolo de invocação, separação entre decisão de rota e execução de fase, o disco como fronteira de estado, o consentimento por corrida do runner, o layout `docs/` e a convenção de promoção. Nada disso vivia em shell.

## Numeração

Este ADR toma o número **0021**. O 0020 foi atribuído na spec 015 e nunca promovido ao diretório canônico; ele permanece onde está, como o ADR-0007 permanece em `specs/archive/004-feature-orchestration-graph/` desde o ADR-0018. Superseder um ADR não promovido não libera o número.
