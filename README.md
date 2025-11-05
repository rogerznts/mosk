# 🚀 MOSK Toolkit

**Mad Open Spec Kit** - Toolkit completo para Spec-Driven Development (SDD)

## 📋 Visão Geral

O MOSK é um toolkit unificado que integra três ferramentas complementares, cada uma projetada para um propósito específico no ciclo de desenvolvimento orientado a especificações. Através da metodologia SDD (Spec-Driven Development), o MOSK garante que todo o processo de desenvolvimento seja documentado, estruturado e rastreável desde a concepção até a entrega.

## 🔧 Componentes do Toolkit

### 1. **BMAD Core** - Discovery & Ideação

**Quando usar:** Fase inicial de discovery, brainstorming e documentação estratégica

**Propósitos:**
- 🔍 **Discovery inicial** de sistemas e projetos
- 📊 **Análise de novas features** e requisitos
- 🏗️ **Arquitetura** de funcionalidades e componentes
- 💡 **Brainstorming** e exploração de soluções
- 👤 **Análise de UX** e experiência do usuário
- 📝 **Geração de documentos** através de agentes especializados

O BMAD Core utiliza agentes inteligentes para produzir documentação de alto nível, como:
- PRDs (Product Requirements Documents)
- Epics e histórias de usuário
- Briefs técnicos e funcionais
- Análises de arquitetura
- Documentos de UX/UI

### 2. **SpecKit** - Implementação & Features

**Quando usar:** Criação e desenvolvimento de features baseadas em especificações

**Propósitos:**
- ✨ **Criação de Features** estruturadas com branches por feature
- 📋 **Implementação baseada em Briefs e PRDs** gerados pelo BMAD
- 🎯 **Desenvolvimento orientado por Epics**
- 🔄 **Rastreabilidade** entre especificação e implementação

O SpecKit transforma a documentação estratégica do BMAD em código mais objetivo, mantendo total alinhamento entre o que foi planejado e o que está sendo desenvolvido.

### 3. **OpenSpec** - Manutenção & Operações

**Quando usar:** Ações rápidas, correções e operações do dia a dia

**Propósitos:**
- 🔧 **GMUD** (Gestão de Mudanças)
- 🐛 **Bugfix** e correções
- 🔥 **Hotfix** emergenciais
- ⚡ **Ações rápidas** e pontuais
- 🚀 **Deploy** e operações

O OpenSpec é otimizado para situações que requerem agilidade, mantendo ainda assim a documentação e rastreabilidade necessárias para operações seguras.

## 🔄 Fluxo de Trabalho SDD

```
1. 🔍 BMAD Core
   └─> Discovery & Análise
       └─> Geração de PRDs, Epics e Briefs
           
2. ✨ SpecKit
   └─> Implementação de Features
       └─> Criação de branches baseadas em especificações
           
3. 🔧 OpenSpec
   └─> Manutenção & Hotfixes
       └─> Correções e mudanças rápidas
```

## 🎯 Benefícios da Abordagem SDD

- **📚 Documentação viva** - Especificações sempre atualizadas
- **🔍 Rastreabilidade** - Do requisito ao código
- **🤝 Colaboração** - Linguagem comum entre times
- **⚡ Agilidade** - Ferramenta certa para cada momento
- **🎨 Qualidade** - Desenvolvimento baseado em especificações claras

## 📖 Como Usar

### 🎯 Sobre Este Repositório

Este repositório é dedicado à **manutenção e administração do MOSK Toolkit**. Ele deve ser gerenciado por alguém que compreende profundamente a metodologia SDD e a estrutura das ferramentas, pois com o tempo será necessário:

- Atualizar agentes e comandos conforme evoluem as necessidades
- Adicionar novos templates e workflows
- Manter a consistência entre as três ferramentas
- Documentar novas funcionalidades e casos de uso

### 📦 Instalação em Projetos

Para instalar o MOSK Toolkit em qualquer projeto (Greenfield ou Brownfield), basta copiar o conteúdo da pasta `mosk` para a raiz do seu projeto:

```bash
# Copie a pasta .cursor e a pasta toolkit para a raiz do seu projeto
cp -r mosk/.cursor /caminho/do/seu/projeto/
cp -r mosk/toolkit /caminho/do/seu/projeto/
```

Estrutura que será copiada:
```
seu-projeto/
├── .cursor/
│   └── commands/          # Slash commands personalizados
└── toolkit/
    ├── .bmad-core/       # Agentes e recursos do BMAD
    ├── .specify/         # Templates e scripts do SpecKit
    └── openspec/         # Configurações do OpenSpec
```

### ⚡ Slash Commands

O MOSK Toolkit utiliza **slash commands customizados** para o Cursor IDE, facilitando o acesso rápido aos agentes e funcionalidades. Todos os comandos estão disponíveis digitando `/` no Cursor.

#### 🧙 BMAD Core - Agentes de Discovery

**`/bmad-master`** - Executor universal de tarefas do BMAD. Use quando precisar de expertise em múltiplas áreas ou executar tarefas pontuais sem ativar uma persona específica. Ideal para criar documentos, executar checklists ou rodar workflows sem transformação de agente.

**`/bmad-orchestrator`** - Orquestrador principal que coordena múltiplos agentes e workflows. Use quando não tiver certeza de qual especialista consultar ou quando precisar coordenar trabalho entre várias áreas. Ele guia você na escolha do agente certo para cada necessidade.

**`/bmad-analyst`** - Analista de negócios especializado em pesquisa de mercado, brainstorming, análise competitiva e criação de project briefs. Use para discovery inicial, pesquisa estratégica e documentação de projetos existentes (brownfield).

**`/bmad-architect`** - Arquiteto de sistemas para design técnico, seleção de tecnologia, design de APIs e planejamento de infraestrutura. Use quando precisar criar documentos de arquitetura (backend, frontend ou fullstack) ou tomar decisões técnicas estruturais.

**`/bmad-dev`** - Desenvolvedor fullstack para implementação de código, debugging e refatoração. Use quando for implementar stories, aplicar correções de QA ou executar o desenvolvimento propriamente dito seguindo as especificações criadas.

**`/bmad-po`** - Product Owner para gestão de backlog, refinamento de stories, critérios de aceitação e planejamento de sprints. Use para validar artefatos, criar epics e stories, ou garantir a integridade e consistência da documentação.

**`/bmad-pm`** - Product Manager para criação de PRDs, estratégia de produto, priorização de features e planejamento de roadmap. Use quando precisar criar documentos de requisitos de produto (PRD) ou definir estratégia e visão de produto.

**`/bmad-qa`** - Test Architect para revisão de arquitetura de testes, decisões de quality gates e avaliação abrangente de qualidade. Use para reviews completos de stories, avaliação de riscos, design de testes e validação de requisitos não-funcionais.

**`/bmad-sm`** - Scrum Master para criação de stories, gestão de epics, retrospectivas e orientação em processos ágeis. Use quando precisar preparar stories detalhadas e acionáveis para desenvolvedores, garantindo clareza e handoffs precisos.

**`/bmad-ux-expert`** - Expert em UX para design de UI/UX, wireframes, protótipos e especificações de front-end. Use quando precisar criar especificações visuais, otimizar experiência do usuário ou gerar prompts para ferramentas de geração de UI (como v0 ou Lovable).

#### 🎯 SpecKit - Desenvolvimento Orientado a Specs

**`/speckit-constitution`** - Cria ou atualiza a constituição do projeto, definindo princípios e regras não-negociáveis que governam todo o desenvolvimento. Use no início do projeto ou quando precisar estabelecer/revisar os princípios fundamentais de qualidade e governança.

**`/speckit-specify`** - Cria uma nova especificação de feature a partir de descrição em linguagem natural. Gera automaticamente uma branch, extrai requisitos, define critérios de sucesso e cria o documento spec.md completo. Use quando iniciar uma nova feature.

**`/speckit-clarify`** - Identifica áreas ambíguas na especificação e faz até 5 perguntas direcionadas para reduzir incertezas. Atualiza automaticamente a spec.md com as respostas. Use após criar a spec para resolver ambiguidades antes do planejamento.

**`/speckit-plan`** - Executa o workflow de planejamento de implementação, gerando artefatos de design (data-model.md, contracts/, research.md). Segue a estrutura do plan.md template para definir arquitetura técnica. Use após a especificação estar clara e validada.

**`/speckit-tasks`** - Gera lista de tarefas ordenadas e acionáveis (tasks.md) baseada nos artefatos de design. Organiza por user story, identifica dependências e oportunidades de paralelização. Use após o planejamento estar completo.

**`/speckit-checklist`** - Cria checklists customizados de qualidade para validar requisitos ("testes unitários para documentação"). Valida completude, clareza e consistência da especificação. Use quando precisar verificar qualidade dos requisitos em domínios específicos.

**`/speckit-analyze`** - Realiza análise de consistência cross-artifacts entre spec.md, plan.md e tasks.md. Detecta duplicações, ambiguidades e gaps de cobertura. Use após gerar tasks para validar antes da implementação.

**`/speckit-implement`** - Executa o plano de implementação processando todas as tarefas do tasks.md. Verifica checklists, segue dependências e reporta progresso. Use quando tudo estiver validado e pronto para implementar.

#### 🔧 OpenSpec - Mudanças Rápidas

**`/openspec-proposal`** - Cria uma proposta de mudança OpenSpec com scaffold completo (proposal.md, tasks.md, design.md). Valida estritamente e mapeia mudanças em specs deltas organizados por capability. Use para GMUDs, bugfixes e mudanças pontuais.

**`/openspec-apply`** - Implementa uma mudança OpenSpec aprovada, executando as tarefas definidas e mantendo sincronia com a proposta. Use após a proposta ser revisada e aprovada para aplicar as mudanças.

**`/openspec-archive`** - Arquiva uma mudança OpenSpec deployada, movendo para o histórico e atualizando as specs principais. Use após deployment bem-sucedido para consolidar as mudanças nas especificações permanentes.

## 🚀 Começando

1. **Instale o toolkit** copiando as pastas `.cursor` e `toolkit` para seu projeto
2. **Inicie com BMAD Core** (`/bmad-orchestrator` ou agentes específicos) para discovery e gerar especificações
3. **Use SpecKit** (`/speckit-specify` → `/speckit-plan` → `/speckit-implement`) para implementar features
4. **Aplique OpenSpec** (`/openspec-proposal`) para manutenções rápidas e correções

---

**MOSK Toolkit** - Transformando especificações em realidade, uma feature por vez.

