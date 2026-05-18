# 🔒 Política de Privacidade - Shopping Comparator

**Última atualização:** 2026-05-18

---

## 1. Apresentação

O **Shopping Comparator** é uma aplicação de comparação de preços **100% descentralizada e anônima**. Esta política descreve como seus dados são coletados, armazenados e processados.

---

## 2. Quem é o Controlador de Dados?

- **Seu dispositivo**: Você é o principal controlador dos seus dados locais
- **Operadores de Estabelecimentos**: Controlam dados sobre a localização de suas lojas
- **A Plataforma**: Opera como facilitadora de rede P2P descentralizada

---

## 3. Quais Dados Coletamos?

### 3.1 Dados Coletados LOCALMENTE (ficam no seu dispositivo)

- **Carrinho de Compras**: Produtos que você adiciona
- **Preços**: Valores de produtos que você registra
- **Histórico**: Timestamps das suas ações
- ❌ **Seu dispositivo não armazena identificação pessoal**

### 3.2 Dados Coletados com CONSENTIMENTO

#### 📍 Localização
- Coletada APENAS quando você autoriza
- Usada para:
  - Identificar se você está dentro de um estabelecimento registrado
  - Determinar se seus dados devem ser compartilhados com a rede
  - Calcular distância de lojas próximas
- **Armazenamento**: Processado localmente, nunca em servidor central
- **Compartilhamento**: Dados de preço são compartilhados APENAS se dentro de geofence

#### 🤖 Processamento de Imagens com IA
- Coletado APENAS quando você autoriza
- Usado para:
  - Ler código de barras em etiquetas de preço
  - Extrair valor numérico automaticamente
- **Processador**: Google Gemini ou Ollama (conforme sua configuração)
- **Privacidade**: Google/Ollama recebem cópia da imagem; você permanece anônimo

### 3.3 Dados NÃO Coletados

- ❌ Seus dados pessoais (nome, email, telefone)
- ❌ Histórico de navegação
- ❌ Informações de dispositivo
- ❌ Cookies ou rastreadores

---

## 4. Como seus Dados são Armazenados?

### Local (seu dispositivo)
- **Armazenamento**: Hive (banco de dados local)
- **Criptografia**: Não (dados armazenados em texto plano no dispositivo)
- **Acesso**: Apenas sua aplicação pode acessar
- **Sincronização**: Automática com rede P2P quando online

### Sincronização P2P
- **Hub Server**: Funciona como retransmissor, não armazena dados permanentemente
- **Encriptação em Trânsito**: WebSocket com TLS (wss://)
- **Identificação**: Seus dados não são vinculados a identificador pessoal

---

## 5. Quanto Tempo seus Dados são Retidos?

- **Carrinho e Preços**: Mantidos localmente enquanto a aplicação existir
- **Hub Server**: Dados não são armazenados (apenas retransmitidos)
- **Limpeza Manual**: Você pode deletar histórico a qualquer momento em Configurações
- **Dados Privados**: Quando fora de geofence, dados não são sincronizados

---

## 6. Seus Direitos (LGPD Art. 18-22)

Você tem direito a:

### ✅ Acessar seus dados
- Todos os dados ficam no seu dispositivo
- Você pode visualizar carrinho, preços, histórico no app

### ✅ Deletar seus dados
- Botão "Apagar histórico local" em Configurações
- Remove todos os dados do seu dispositivo instantaneamente

### ✅ Corrigir seus dados
- Você pode editar preços/produtos diretamente no app

### ✅ Exportar seus dados
- Dados estão em Hive (SQLite), acessível localmente
- Não há endpoint centralizado para exportação

### ✅ Opor-se ao processamento
- Toggle "Compartilhamento de Localização" em Configurações
- Toggle "Processamento de Imagens com IA" em Configurações

---

## 7. Segurança

### Protegido ✅
- Dados locais isolados por aplicação (SO protege)
- Sincronização via WebSocket TLS
- Assinatura HMAC para mensagens oficiais de operadores

### NÃO Protegido ❌
- Dados em repouso no dispositivo não são criptografados
- Se alguém acessar o dispositivo, pode ver dados locais
- **Recomendação**: Use bloqueio de tela/biometria do SO

---

## 8. Processamento Externo

### Google Gemini (se configurado)
- **O quê**: Imagens de etiquetas de preço
- **Por quê**: Extrair valor numérico
- **Controle**: Você pode desabilitar em Configurações
- **Política**: Consulte https://policies.google.com/privacy

### Ollama (se configurado)
- **O quê**: Imagens de etiquetas de preço
- **Por quê**: Extrair valor numérico (localmente no seu servidor)
- **Controle**: Você pode desabilitar em Configurações
- **Política**: Ollama é de código aberto e roda localmente

---

## 9. Consentimento

### Primeira Abertura
- Você verá um diálogo explicando como a privacidade funciona
- Deve clicar "Entendi, continuar" para usar o app

### Primeira Coleta de Localização
- Diálogo pedindo consentimento
- Você pode recusar; dados não serão compartilhados com rede

### Primeira Imagem de Etiqueta
- Diálogo aviso que imagem será enviada para IA
- Você pode cancelar a operação

### Gerenciar Consentimentos
- Vá em Configurações → Resetar Consentimentos
- Você verá os diálogos novamente na próxima ação

---

## 10. Alterações nesta Política

Podemos atualizar esta política. Mudanças importantes serão comunicadas via app.

---

## 11. Contato

Para dúvidas sobre privacidade, abra uma issue em:
https://github.com/seu-usuario/shopping-comparator

---

## 12. Conformidade LGPD

Esta aplicação segue os princípios da **Lei Geral de Proteção de Dados (LGPD - Lei 13.709/2018)**:

- ✅ **Transparência**: Você sabe quais dados são coletados e por quê
- ✅ **Consentimento**: Dados sensíveis requerem sua autorização
- ✅ **Anonimidade**: Nenhuma identificação pessoal vinculada
- ✅ **Segurança**: TLS em trânsito, isolamento no dispositivo
- ✅ **Direitos**: Acesso, deleção, correção e oposição disponíveis
