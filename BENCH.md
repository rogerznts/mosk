# 🛠️ MOSK Bench — crie suas próprias ferramentas de trabalho, sem saber programar

> **Você descreve o que precisa. O Bench constrói, testa e entrega — funcionando.**
>
> Uma ferramenta interna feita sob medida para o seu trabalho, em português,
> sem uma única decisão técnica da sua parte.

---

## O que é isso, em uma frase

O **Bench** (comandado pelo assistente **Bento**) é um modo de trabalho do MOSK
que transforma um pedido em linguagem do dia a dia — *"preciso de um cadastro de
clientes com aprovação do gerente"* — em um **sistema de verdade, rodando no seu
computador**, com tela de login, telas de cadastro e regras do seu negócio já
aplicadas.

Você conversa. Ele pergunta o que for preciso. Ele monta. Ele testa sozinho.
Ele te entrega o endereço para abrir no navegador.

**Nenhum código. Nenhum termo técnico. Nenhuma instalação manual.**

---

## Para quem é

- Pessoas de **negócio, operações, RH, comercial, financeiro** — qualquer área
  que hoje se vira com planilhas soltas e queria uma ferramentinha própria.
- Quem **não é da área de tecnologia** e nunca vai querer ser.
- Quem precisa **criar e testar rápido** uma ideia sem depender de fila de TI.

Se você sabe descrever o seu problema, você sabe usar o Bench.

---

## Como funciona — em 4 passos

### 1. Você ativa o modo
Digite **`/mosk-bench`** e diga, com suas palavras, o que quer criar.

### 2. Ele te entrevista (só sobre o seu negócio)
O Bento faz perguntas **uma de cada vez**, sempre em português claro, e **só
sobre o que ele não pode adivinhar sozinho**:
- Que informações a ferramenta vai guardar?
- Quem acessa? Quem pode fazer o quê?
- Quais são as regras? (*"só o gerente aprova"*, *"não pode repetir CPF"*…)

👉 **Ele nunca te pergunta nada técnico.** Banco de dados, servidor, código —
tudo isso ele decide por você, escolhendo sempre a opção segura. Se uma escolha
sua tiver implicação técnica, ele resolve e apenas te **avisa** em português.

Ele só para de perguntar quando **entendeu tudo** — e você pode dizer *"chega"*
a qualquer momento.

### 3. Ele constrói e testa — sozinho
Com o pedido entendido, o Bench monta a ferramenta e **testa cada regra que você
pediu**, automaticamente. Se algo não passa, ele conserta e testa de novo, até
ficar tudo verde. Você não vê a bagunça do processo — só o resultado.

### 4. Você recebe pronto
No fim, ele te dá:
- 🔗 o **endereço** para abrir no navegador (ex.: `http://localhost:3000`),
- 🔑 o **login e senha** para entrar,
- ✅ um **resumo em português** do que foi criado e do que foi testado.

---

## O que você ganha

| ✔️ | |
|---|---|
| **Tudo em português** | O sistema inteiro — telas, menus, botões — nasce em português do Brasil. |
| **Já vem com login** | Controle de acesso e senha prontos desde o primeiro minuto. |
| **Zero instalação na sua máquina** | Roda tudo em contêineres isolados (Docker). Nada suja o seu computador. |
| **Testado de verdade** | Cada regra que você pediu vira um teste automático que precisa passar. |
| **Seus dados isolados** | Cada ferramenta tem seu próprio espaço; uma nunca enxerga a outra. |
| **Cresce com você** | Peça mudanças depois — ele evolui a ferramenta sem começar do zero. |

---

## O que dá para criar (exemplos)

Pense em qualquer coisa que hoje vive numa planilha bagunçada:

- 📇 **Cadastro de clientes** — com e-mail único e histórico.
- ✅ **Controle de tarefas** — com responsável e status, e *"só o gerente conclui"*.
- 📦 **Controle de estoque** — produtos, quantidades, alertas.
- 📝 **Fluxo de aprovações** — pedidos que só avançam depois do OK de alguém.
- 👥 **Base de fornecedores, contratos, chamados, agendamentos…**

Cada "assunto" que a sua ferramenta guarda (clientes, produtos, tarefas…) vira um
**módulo próprio no menu** — todos sempre visíveis, nada escondido.

---

## Duas coisas que fazem o Bench diferente

### 🎯 Ele te entrevista de verdade (o "grill")
Em vez de adivinhar e errar, o Bento **cava** cada detalhe do seu pedido, uma
pergunta por vez, sempre sugerindo uma resposta recomendada. O resultado é uma
ferramenta que faz **exatamente** o que você quis dizer — não o que ele achou que
você quis.

### 🔁 Ele não entrega no escuro
O Bench só considera a ferramenta pronta quando **todos os testes passam**. Ele
tenta, conserta e re-testa em ciclo fechado. Se esbarrar em algo que depende de
uma decisão sua de negócio, ele **para e te pergunta** — nunca inventa uma regra
que você não deu.

---

## Precisa de mudança depois? É só pedir

Semana que vem você quer adicionar um campo, um novo módulo ou uma nova regra?
Ative o `/mosk-bench` de novo dentro do mesmo projeto. Ele **reconhece** a
ferramenta que já existe, pergunta só sobre a novidade e **evolui** o que você já
tem — sem refazer nada e sem perder seus dados. Cada mudança fica **registrada no
histórico**, então dá para ver como a ferramenta cresceu ao longo do tempo.

---

## E se eu não tiver o Docker instalado?

Sem problema. O Bench checa o ambiente por você e, se faltar o Docker (o motor que
roda tudo de forma isolada), ele te mostra o comando oficial e **pede sua
autorização** antes de instalar. Nada acontece sem o seu "sim".

---

## Como começar

```text
/mosk-bench
```

E então, com suas palavras:

> *"Quero uma ferramenta para cadastrar meus clientes, com nome e e-mail, e só
> eu (administrador) posso excluir um cliente."*

O resto é com o Bento. ☕

---

## Perguntas rápidas

**Preciso saber programar?**
Não. Se você fizer isso, algo deu errado — o Bench existe justamente para você
*não* precisar.

**Meus dados ficam seguros?**
Sim. Cada ferramenta tem seu próprio banco de dados isolado, rodando localmente
em contêineres. Nada é publicado na internet por conta própria.

**Funciona no Claude Code e no Codex?**
Sim. A experiência é equivalente nos dois.

**E se eu pedir algo impossível ou incompleto?**
Ele te avisa em português, explica o que ficou pendente e não finge que está
pronto quando não está.

---

> **Bench** é o modo. **Payload** é a tecnologia que ele usa por baixo hoje
> (você nunca precisa saber disso). Amanhã pode ser outra — para você, nada muda:
> é sempre *"descreva o que precisa, receba a ferramenta pronta"*.

*Parte do [MOSK](./README.md) · comando `/mosk-bench` · persona Bento.*
