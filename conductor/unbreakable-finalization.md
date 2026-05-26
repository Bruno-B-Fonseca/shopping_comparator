# Plano: Automação de Handshake e Documentação Final "Inquebrável"

Este plano visa automatizar a última milha da conectividade do Nó Local e documentar os avanços de resiliência conquistados.

## Objetivos
1.  **Automação do Makefile**: Implementar a extração automática da URL do túnel efêmero do Cloudflare e seu anúncio ao Hub.
2.  **Documentação de Progresso**: Formalizar os marcos da arquitetura "Inquebrável" nos arquivos de registro do projeto.

## Mudanças Propostas

### 1. `Makefile`
- Atualizar o alvo `node-up` para:
    - Iniciar os containers em background.
    - Executar um loop de monitoramento (máximo 10 tentativas) nos logs do container `tunnel`.
    - Extrair a URL `https://*.trycloudflare.com`.
    - Transformá-la para o formato WebSocket Seguro (`wss://.../ws`).
    - Realizar o `POST` automático para `http://localhost:3000/api/announce-url`.

### 2. Documentação
- Verificar e complementar o `CHANGELOG.md` e `IMPLEMENTATION_SUMMARY.md` com os detalhes técnicos do **Modo Standalone** e **Geo-Discovery**.

## Verificação e Testes
1.  Executar `make node-down && make node-up`.
2.  Observar no console se a URL é detectada e anunciada automaticamente.
3.  Verificar no log do `websocket` se o Hub recebeu a nova URL.
4.  Validar se o App no navegador continua acessível via `/app`.

## Rollback
- Reverter o `Makefile` para a versão simples de `docker-compose up -d`.
