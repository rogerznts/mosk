# ADR-0005 — Deploy como skill opt-in separada, fora das invariantes de dev local

- Status: aceito
- Data: 2026-07-20
- Autor: Maria (mosk-analyst) + Vinicius (mosk-architect)
- Contexto: skill `/mosk-deploy` — publicar ferramentas criadas pelo `/mosk-bench`.
- Relacionado: [[adr-0001-shared-infra-model]], [[adr-0003-versioned-golden-starter]], [[adr-0002-auto-escalation-exception]].

## Contexto

O modo `/mosk-bench` entrega ferramentas **rodando localmente** e trata
**produção/deploy como fora de escopo** por design. Suas invariantes protegem o
leigo:

- **INV-4**: zero build local, nada instalado além do Docker; o app roda `pnpm dev`
  (`NODE_ENV: development`), com Postgres/Redis da infra local compartilhada
  (ADR-0001).
- **INV-5/INV-6**: nada técnico é exposto ao leigo; a entrega é sempre
  `http://localhost:<porta>`.

Publicar a ferramenta num servidor introduz, inevitavelmente, conceitos de
produção: **conta num provedor**, **serviços gerenciados**, **build de produção**,
**segredos** e uma **URL pública**. Encaixar isso dentro do fluxo do bench colidiria
frontalmente com INV-4 (build) e com o contrato de entrega localhost.

## Decisão

Deploy é uma **skill separada e opt-in** (`/mosk-deploy`), **não** uma fase do
bench. O bench permanece 100% local e intocado. A skill de deploy é uma **nova
capacidade do adapter** (dimensões plugáveis: *stack* × *provedor*), com um driver
determinístico por stack (`payload-deploy.sh`; provedor default: Railway).

Reconciliação com as invariantes:

- **INV-4 preservada.** O `build` de produção roda **no provedor (remoto)**. Nada é
  buildado na máquina do usuário — a máquina só precisa do que o bench já exige. A
  proibição de INV-4 é de build **local**, e o deploy não faz build local.
- **Starter dev intocado.** O deploy **gera** um overlay de produção
  (`Dockerfile.production`, `railway.json`, variáveis de produção) **sem** alterar o
  `docker-compose.yml`/`pnpm dev`/localhost do projeto. As duas realidades (dev local
  e produção remota) coexistem.
- **Exceção escopada a INV-5/INV-6.** O deploy expõe, no mínimo, "sua ferramenta está
  em `<URL pública>`" — um conceito de produção que o bench esconderia. Essa exceção é
  **estreita e explícita**, no espírito do ADR-0002: o leigo decide **apenas**
  conta/token e nome público; todo o resto (serviços gerenciados, env, build,
  migrations) é convenção determinística, e o barulho técnico fica fora da vista.
- **Token via ambiente.** O token do provedor entra por variável de ambiente, nunca
  em flag — alinhado à prática da agent-skill oficial da Vercel.

## Consequências

- **Positivas:** o bench não é contaminado por produção; a mesma ferramenta ganha um
  caminho de publicação sem perder o ambiente local; o modelo stack × provedor deixa
  a porta aberta para PHP (futuro adapter) e para Vercel/Fly (futuros drivers) sem
  reescrever o roteiro.
- **Custo/acoplamento:** deploy pressupõe **conta (paga) no provedor** e serviços
  gerenciados — assumido explicitamente. A ferramenta publicada passa a depender do
  provedor; a versão local segue independente.
- **Não coberto por este ADR:** adapter PHP e drivers Vercel/Fly (só o desenho
  genérico existe agora); domínio customizado, CI/CD por git push e rollback são
  aditivos posteriores.

## Alternativas rejeitadas

- **Deploy como Fase 7 do bench:** quebraria INV-4 e o contrato de entrega localhost
  dentro do próprio modo; misturaria dev e produção num fluxo pensado para ser local.
- **Buildar a imagem de produção localmente e dar push:** violaria INV-4 (build
  local) e exigiria mais da máquina do leigo. Deixar o provedor buildar é mais simples
  e preserva a invariante.
