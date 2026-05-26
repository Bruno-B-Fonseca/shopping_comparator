# Shopping Comparator: Onboarding de Hubs (Redes/Franquias)

Bem-vindo à arquitetura federada do Shopping Comparator. Este guia é para redes que desejam operar como um **Hub Regional**, centralizando a gestão de suas filiais.

## 1. O que é um Hub?
Um Hub é um nó intermediário na nossa rede. Ele permite:
- **Agregação**: Centralizar o catálogo e preços das suas filiais.
- **Governança**: Definir regras e promoções para todo o grupo.
- **Federação**: Integrar seu grupo à rede nacional mantendo a soberania dos dados.

## 2. Pré-requisitos
- **Docker e Docker Compose** instalados.
- **Acesso à internet**.

## 3. Configuração do Hub
Utilize o `docker-compose-hub.yml` como base.

### Passo A: Criar seu arquivo .env
Configure os identificadores da sua rede:
```bash
# Identificação da sua rede
HUB_ID=id-da-rede-farmacia
HUB_SECRET=sua-chave-secreta-de-federacao

# Porta do Hub (padrão 3000)
HUB_PORT=3000
```

### Passo B: Subir o Hub
```bash
docker-compose -f docker-compose-hub.yml up -d --build
```

## 4. Conectando suas Filiais (Nós de Borda)
Cada filial deve ser configurada apontando para o seu **Hub Regional** em vez do Hub Nacional.

No `.env` da filial, adicione:
```bash
HUB_URL=https://hub.sua-rede.com
```

## 5. Integração com o Hub Nacional
Para que sua rede apareça na rede nacional:
1. **Registro**: Entre em contato para registrar seu `HUB_ID`.
2. **Announce**: Seu Hub enviará periodicamente um manifesto ao Hub Nacional contendo a lista de filiais ativas.

---
Para suporte técnico, entre em contato através dos nossos canais oficiais.
