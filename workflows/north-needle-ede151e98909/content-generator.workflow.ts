import { workflow, node, links } from '@n8n-as-code/transformer';

// <workflow-map>
// Workflow : Gerador de Conteúdo Social
// Nodes   : 3  |  Connections: 2
//
// NODE INDEX
// ──────────────────────────────────────────────────────────────────
// Property name                    Node type (short)         Flags
// TelegramTrigger                    telegramTrigger
// AiGenerator                        openAi
// SendOptions                        telegram
//
// ROUTING MAP
// ──────────────────────────────────────────────────────────────────
// TelegramTrigger
//    → AiGenerator
//      → SendOptions
// </workflow-map>

// =====================================================================
// METADATA DU WORKFLOW
// =====================================================================

@workflow({
    id: 'hJyACTkLUCJPkGvN',
    name: 'Gerador de Conteúdo Social',
    active: false,
    isArchived: false,
    settings: { executionOrder: 'v1', callerPolicy: 'workflowsFromSameOwner', availableInMCP: false },
})
export class GeradorDeConteudoSocialWorkflow {
    // =====================================================================
    // CONFIGURATION DES NOEUDS
    // =====================================================================

    @node({
        id: '4352b99b-f0be-47bb-8a11-22d51e067b98',
        name: 'Telegram Trigger',
        type: 'n8n-nodes-base.telegramTrigger',
        version: 1.1,
        position: [250, 300],
    })
    TelegramTrigger = {
        updates: ['message'],
    };

    @node({
        id: '75327636-bac8-4074-b5f5-26b809a64d84',
        name: 'AI Generator',
        type: 'n8n-nodes-base.openAi',
        version: 1.1,
        position: [450, 300],
    })
    AiGenerator = {
        resource: 'chat',
        operation: 'complete',
        chatModel: 'gpt-3.5-turbo',
        prompt: {
            messages: [
                {
                    role: 'user',
                    content:
                        'Crie 3 versões de post para Instagram sobre o tema: {{ $json.message.text }}. 1 emocional, 1 técnico, 1 educativo. Foco: shopcomp.org, utilidade, controle de orçamento e transparência.',
                },
            ],
        },
    };

    @node({
        id: '4e7d3050-e3d9-440a-a2ce-6e60696b4075',
        name: 'Send Options',
        type: 'n8n-nodes-base.telegram',
        version: 1.2,
        position: [650, 300],
    })
    SendOptions = {
        resource: 'message',
        operation: 'sendMessage',
        chatId: '{{ $json.message.chat.id }}',
        text: '{{ $json.choices[0].message.content }}',
    };

    // =====================================================================
    // ROUTAGE ET CONNEXIONS
    // =====================================================================

    @links()
    defineRouting() {
        this.TelegramTrigger.out(0).to(this.AiGenerator.in(0));
        this.AiGenerator.out(0).to(this.SendOptions.in(0));
    }
}
