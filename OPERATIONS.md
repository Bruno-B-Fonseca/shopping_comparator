# Manual de Operações: ShopComp.org (n8n Edition)

Este manual é o guia de referência rápida para gerenciar as automações do ShopComp.org.

## 1. Credenciais (Configuração Inicial)
Para que os workflows funcionem, configure as credenciais no painel do n8n:
*   **Google Sheets**: Crie uma conta de serviço no Google Cloud, ative a API do Sheets e insira as credenciais no n8n.
*   **OpenAI**: Adicione sua API Key na seção "Credentials" (Tipo: OpenAI API).
*   **Telegram**: Caso utilize, insira o Token do bot criado no @BotFather.
*   **SMTP (E-mail)**: Configure as credenciais do seu provedor de e-mail no nó de envio.

## 2. Workflows Ativos

### A. Captura de Leads (Pioneiros)
*   **Objetivo**: Salvar interessados da Landing Page na Planilha "Leads".
*   **Checklist**:
    *   Workflow deve estar **[Active]**.
    *   Planilha "Leads" deve existir com colunas: `name`, `type`, `email`.

### B. Gerador de Conteúdo Social
*   **Objetivo**: Gerar ideias de posts via Telegram.
*   **Uso**: Envie um tema para o bot do Telegram; ele responderá com versões (emocional, técnico, educativo).

### C. Guardião da Federação (Health Check)
*   **Objetivo**: Monitorar se o Hub e a instância local estão online.
*   **Rotina**: Automática (cada 30 min).
*   **Alerta**: Em caso de falha, um e-mail de alerta será enviado para o endereço definido em `OWNER_EMAIL`.

## 3. Comandos de Manutenção (CLI)

Use o terminal no diretório raiz do projeto (`/home/bruno-fonseca/develop/projects/shopping_comparator/`):

| Tarefa | Comando |
| :--- | :--- |
| **Listar Workflows** | `npx --yes n8nac list` |
| **Status do Ambiente** | `npx --yes n8nac workspace status --json` |
| **Puxar (Pull)** | `npx --yes n8nac pull <workflowId>` |
| **Empurrar (Push)** | `npx --yes n8nac push <path.workflow.ts> --verify` |

## 4. Diagnóstico
*   **Execuções**: Acesse o painel n8n -> menu **"Executions"**. É onde você visualiza cada tentativa de execução, nós que falharam e os dados recebidos.
*   **Logs**: Caso o n8n pare de responder, verifique os logs dos containers: `docker ps` e `docker logs <container_id>`.
