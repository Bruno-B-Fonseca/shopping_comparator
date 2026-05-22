import { workflow, node, links } from '@n8n-as-code/transformer';

// <workflow-map>
// Workflow : Monitor de Preços
// Nodes   : 4  |  Connections: 3
//
// NODE INDEX
// ──────────────────────────────────────────────────────────────────
// Property name                    Node type (short)         Flags
// ScheduleTrigger                    scheduleTrigger
// HttpRequest                        httpRequest
// CheckPrice                         if
// SlackNotification                  slack
//
// ROUTING MAP
// ──────────────────────────────────────────────────────────────────
// ScheduleTrigger
//    → HttpRequest
//      → CheckPrice
//        → SlackNotification
// </workflow-map>

// =====================================================================
// METADATA DU WORKFLOW
// =====================================================================

@workflow({
    id: '7DYP2an6ERPcRji7',
    name: 'Monitor de Preços',
    active: false,
    isArchived: false,
    settings: { executionOrder: 'v1', callerPolicy: 'workflowsFromSameOwner', availableInMCP: false },
})
export class MonitorDePrecosWorkflow {
    // =====================================================================
    // CONFIGURATION DES NOEUDS
    // =====================================================================

    @node({
        id: '88dcc65e-64fc-4c97-83f7-9f72f8918033',
        name: 'Schedule Trigger',
        type: 'n8n-nodes-base.scheduleTrigger',
        version: 1.3,
        position: [250, 300],
    })
    ScheduleTrigger = {
        rule: {
            interval: [
                {
                    field: 'days',
                    daysInterval: 1,
                },
            ],
        },
    };

    @node({
        id: 'b3765511-da63-427a-97b5-af0ae1f2bea5',
        name: 'HTTP Request',
        type: 'n8n-nodes-base.httpRequest',
        version: 4.1,
        position: [450, 300],
    })
    HttpRequest = {
        method: 'GET',
        url: 'https://api.example.com/product/price',
        sendQuery: true,
        queryParameters: {
            parameters: [
                {
                    name: 'productId',
                    value: '123',
                },
            ],
        },
        options: {},
    };

    @node({
        id: 'abbb95ff-8173-45c0-ac20-424f63e42a29',
        name: 'Check Price',
        type: 'n8n-nodes-base.if',
        version: 2.3,
        position: [650, 300],
    })
    CheckPrice = {
        conditions: {
            number: [
                {
                    value1: '{{ $json.price }}',
                    operation: 'smaller',
                    value2: 100,
                },
            ],
            options: {
                caseSensitive: true,
                typeValidation: 'strict',
            },
        },
    };

    @node({
        id: '43d2562b-17ad-4e2a-a3f7-42a0e4fe795b',
        name: 'Slack Notification',
        type: 'n8n-nodes-base.slack',
        version: 2.4,
        position: [850, 200],
    })
    SlackNotification = {
        resource: 'message',
        operation: 'post',
        select: 'channel',
        channelId: {
            mode: 'list',
            value: 'general',
        },
        text: 'Preço abaixo de 100! Valor: {{ $json.price }}',
    };

    // =====================================================================
    // ROUTAGE ET CONNEXIONS
    // =====================================================================

    @links()
    defineRouting() {
        this.ScheduleTrigger.out(0).to(this.HttpRequest.in(0));
        this.HttpRequest.out(0).to(this.CheckPrice.in(0));
        this.CheckPrice.out(0).to(this.SlackNotification.in(0));
    }
}
