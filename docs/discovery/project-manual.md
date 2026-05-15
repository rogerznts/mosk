Este documento estabelece os critérios técnicos e comportamentais utilizados pelo auditor PMO para avaliar a saúde, a organização e a fluidez dos projetos geridos na nossa ferramenta.

O objetivo desta metodologia não é apenas cobrar, mas reduzir o esforço cognitivo do time, garantindo que qualquer colaborador, ao olhar para o projeto, entenda imediatamente o que deve ser feito, como deve ser feito e qual o critério de sucesso.

---

## 1. O Padrão de Escopo (Regra do Tripé)

A base fundamental da organização é a clareza. Todo item cadastrado (seja o **Projeto Principal** ou uma **Subtarefa**) deve, obrigatoriamente, conter na descrição o "Tripé de Definição":

1. **Resumo:** O que é a tarefa de forma sucinta.
2. **Planejamento:** O "como fazer" (passo a passo, checklist ou tópicos de execução).
3. **Entregável:** A definição clara de "Pronto" (o critério de sucesso ou o resultado esperado).

Mecanismo de Apoio:

Caso um item não possua essa estrutura, a avaliação analisará o contexto para gerar automaticamente uma sugestão de rascunho para o colaborador. 

---

## 2. Rastreabilidade e Evidência (Protocolo Nexus)

Para garantir que o histórico do projeto seja preservado e acessível:

- **Critério de Conclusão (Done):** É vedado marcar uma tarefa como "Done" (Feito) sem evidência.
- **Ação Necessária:** Todo item finalizado deve conter um **Link (Nexus)** ou um **Anexo** nos comentários que comprove a entrega (print, documento, URL, etc.). Se não houver evidência, o item será apontado como pendente de documentação.

---

## 3. Ritmo e Estagnação (Pulsação)

Projetos ativos precisam demonstrar movimento para evitar bloqueios silenciosos.

- **Regra dos 7 Dias:** Tarefas com status "In Progress" (Em andamento) que não recebem atualização (comentário, mudança de status ou anexo) há mais de 7 dias são sinalizadas como **Estagnadas**.
- **Ação Esperada:** O responsável deve atualizar o status ou comentar sobre eventuais impedimentos.

---

## 4. Auditoria de Metadados Estruturais

A organização técnica garante que os dados gerem relatórios confiáveis para a diretoria. São auditados os seguintes pontos:

**No Nível do Projeto (Responsabilidade do Gestor do Projeto):**

- **Vínculo Estratégico:** O projeto deve estar ligado a um **Módulo (Iniciativa)** do Portfólio Executivo (ex: Expansão, Integração ERP, Governança de Dados).
- **Classificação:** O **Label (Setor)** deve estar correto (Comercial, Operacional, Tecnologia, Financeiro).
- **Datas:** Existência de Data de Início e Data Alvo (Target Date).
- **Composição:** Projetos não podem estar vazios; devem possuir tarefas filhas cadastradas.
- **Descrição:** O Projeto "pai" também deve seguir a regra do Tripé (Resumo, Planejamento, Entregável).

**No Nível da Tarefa (Responsabilidade do Assignee/Executor):**

- **Atribuição:** Toda tarefa deve ter um **Assignee** (Responsável) definido.
- **Prazos:** Definição de Data de Início e Fim.
- **Dependência Cruzada:** Verificação se a tarefa, embora esteja em um projeto de um setor (ex: Comercial), depende tecnicamente de outro setor (ex: Tecnologia ou Financeiro) para correta sinalização aos Heads.

---

## 5. Dinâmica de Feedback e Comunicação

A avaliação gera um relatório direto e acionável, seguindo a hierarquia de responsabilidades:

1. **Feedback Direcionado:** As solicitações são feitas diretamente ao usuário responsável pela tarefa específica (Assignee), de forma educada e propositiva.
2. **Papel do Gestor do Projeto:** O gestor do projeto é cobrado especificamente pela estrutura macro (Metadados do Projeto, Descrição do Projeto Principal e Cronograma Geral). Ele **não** é acionado para microgerenciar tarefas que já possuem outros responsáveis nomeados, exceto se houver bloqueio crítico.
3. **Intervenção de Heads:** Os líderes de área (Tecnologia, Financeiro, Comercial, Operacional) são mencionados apenas quando há dependências entre setores ou bloqueios que exigem decisão hierárquica superior.