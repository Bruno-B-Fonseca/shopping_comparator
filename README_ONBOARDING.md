# Shopping Comparator: Onboarding de Estabelecimentos

Bem-vindo à rede federada Shopping Comparator. Este guia descreve como conectar o seu estabelecimento à nossa rede nacional de forma segura, privada e eficiente.

## 1. Pré-requisitos
- **Docker e Docker Compose** instalados no servidor local.
- Acesso à internet.

## 2. Configuração do seu Nó (L1)
Crie um arquivo chamado `docker-compose.yml` (ou use o nosso `docker-compose-node.yml`) e preencha as variáveis de ambiente necessárias.

### Passo A: Criar seu arquivo .env
Copie o `.env.example` e preencha com seus dados:
```bash
# Identificação do seu mercado
LOCATION_ID=seu-cnpj-ou-id
LOCATION_PASSWORD=sua-senha-segura
LAT=-23.5505
LNG=-46.6333

# Credenciais Cloudflare (Zero Trust)
CLOUDFLARE_TUNNEL_TOKEN=seu-token-aqui
```

### Passo B: Docker Compose
Certifique-se de ter o arquivo `docker-compose-node.yml` no diretório.

## 3. Como obter o TUNNEL_TOKEN (Cloudflare Zero Trust)
Para que seu servidor seja acessível na rede de forma segura, usamos o **Cloudflare Tunnel**:
1. Acesse o painel [Cloudflare Zero Trust](https://one.dash.cloudflare.com/).
2. Vá em **Networks > Tunnels**.
3. Clique em **Create a tunnel** (escolha *cloudflared*).
4. Dê um nome ao túnel (ex: `mercado-seu-nome`).
5. Copie o **Token** (uma string longa) fornecido na tela de instalação.
6. Cole esse token no seu arquivo `.env` na variável `CLOUDFLARE_TUNNEL_TOKEN`.

---

## 4. Alternativa: Túnel Temporário (Sem Zero Trust)
Se você ainda não possui um token Cloudflare configurado e precisa de um túnel de desenvolvimento/teste rápido, você pode rodar um túnel temporário diretamente via linha de comando:

1. **Suba seu servidor normalmente**:
   ```bash
   docker-compose -f docker-compose-node.yml up -d
   ```
2. **Execute o túnel em paralelo**:
   Se você tiver o `cloudflared` instalado na sua máquina, rode:
   ```bash
   cloudflared tunnel --url http://localhost:8081
   ```
3. **Obtenha a URL**: O comando acima imprimirá uma URL `https://xxxx.trycloudflare.com`.
4. **Anuncie ao Hub**: Informe a URL ao seu servidor local via API:
   ```bash
   curl -X POST http://localhost:3000/api/announce-url -d '{"url": "https://xxxx.trycloudflare.com"}'
   ```
   O servidor notificará o Hub Nacional automaticamente e você aparecerá no mapa em segundos.

*Nota: O túnel temporário é para testes. Para uso comercial permanente, o Cloudflare Zero Trust (Passo 3) é altamente recomendado pela segurança e estabilidade.*

## 5. Subindo o seu Mercado
Para iniciar a operação:
```bash
# Subir serviços
docker-compose -f docker-compose-node.yml up -d --build

# Verificar status
docker-compose -f docker-compose-node.yml logs -f websocket
```

O sistema automaticamente se conectará ao Hub e anunciará sua localização para os usuários da região!
