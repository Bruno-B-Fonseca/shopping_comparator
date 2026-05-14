# Backlog: Implementação de Captura de Preço (OCR & AI)

## Objetivo
Implementar automação na captura de preços via OCR (on-device) e, opcionalmente, inferência via IA para aumentar a precisão dos dados do `PriceUpdate` e reduzir erros de entrada manual.

---

## Fase 1: Preparação e Infraestrutura
- [ ] **Configuração do OCR**: Adicionar `google_mlkit_text_recognition` às dependências do cliente.
- [ ] **Serviço de Imagem**: Refatorar ou criar um serviço `PriceExtractionService` para encapsular a lógica de processamento de imagens.
- [ ] **Segurança**: Garantir que as permissões de câmera estejam configuradas corretamente no `AndroidManifest.xml` e `Info.plist`.

## Fase 2: Interface e UX (Scanner Flow)
- [ ] **UI Scanner**: Adicionar botão "Capturar Preço" no `BarcodeScannerWidget` ou na tela de detalhes do produto.
- [ ] **Overlay de Captura**: Criar UI para o usuário tirar a foto da etiqueta.
- [ ] **Feedback**: Adicionar indicadores visuais enquanto o OCR processa (e.g., CircularProgressIndicator).

## Fase 3: Lógica de Processamento (OCR)
- [ ] **Implementação ML Kit**: Conectar a câmera ao `TextRecognizer`.
- [ ] **Parser de Preço**: Implementar regex para identificar padrões de moeda (ex: "R$ 10,00", "10,00") nos blocos de texto extraídos.
- [ ] **Confirmação do Usuário**: Criar tela de "revisão" onde o preço extraído é exibido para o usuário editar/confirmar antes de salvar no `PriceUpdate`.

## Fase 4: Inteligência (Auto-hospedado)
- [ ] **Interface de Visão Local**: Implementar rota no `server/` para processamento de imagem via modelo local (ex: Qwen-VL via Ollama ou binário compatível).
- [ ] **Fallbacks**: Estruturar o fluxo: OCR local (rápido) -> Se falhar/ambíguo -> Modelo de Visão Local (avançado) -> Se falhar -> Manual.
- [ ] **Configuração do Ambiente**: Documentar no `README.md` como o usuário pode subir seu serviço de visão local (ex: via Docker Compose).

## Fase 5: Validação e Dados
- [ ] **Atualização do Modelo**: Adicionar `captureMethod` (manual, ocr, ai) no `PriceUpdate` para fins de auditoria de confiança.
- [ ] **Testes de Integração**: Testar o fluxo completo com diferentes tipos de etiquetas (diferentes fontes e layouts).

---
*Status: Planejado*
