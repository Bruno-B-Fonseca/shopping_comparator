import { workflow, node, links } from '@n8n-as-code/transformer';

// <workflow-map>
// Workflow : Guardião da Federação (Health Check)
// Nodes   : 5  |  Connections: 5
//
// NODE INDEX
// ──────────────────────────────────────────────────────────────────
// Property name                    Node type (short)         Flags
// Schedule30min                      scheduleTrigger
// PingHub                            httpRequest
// PingLocal                          httpRequest
// ErrorCheck                         if
// SendEmailAlert                     emailSend
//
// ROUTING MAP
// ──────────────────────────────────────────────────────────────────
// Schedule30min
//    → PingHub
//      → ErrorCheck
//        → SendEmailAlert
//    → PingLocal
//      → ErrorCheck (↩ loop)
// </workflow-map>

// =====================================================================
// METADATA DU WORKFLOW
// =====================================================================

@workflow({
    id: 'wr4eFr8hBypoNwDt',
    name: 'Guardião da Federação (Health Check)',
    active: false,
    isArchived: false,
    settings: { executionOrder: 'v1', callerPolicy: 'workflowsFromSameOwner', availableInMCP: false },
})
export class GuardiaoDaFederacaoHealthCheckWorkflow {
    // =====================================================================
    // CONFIGURATION DES NOEUDS
    // =====================================================================

    @node({
        id: '2effb8cb-7f73-4815-92ff-721d784baf37',
        name: 'Schedule (30min)',
        type: 'n8n-nodes-base.scheduleTrigger',
        version: 1.3,
        position: [250, 300],
    })
    Schedule30min = {
        rule: {
            interval: [
                {
                    field: 'minutes',
                    minutesInterval: 30,
                },
            ],
        },
    };

    @node({
        id: '5ca6eb31-6fd6-4fbb-92c9-6c5e459bc1e6',
        name: 'Ping Hub',
        type: 'n8n-nodes-base.httpRequest',
        version: 4.1,
        position: [450, 200],
    })
    PingHub = {
        method: 'GET',
        url: '{{ $env.HUB_URL }}/health',
        options: {
            timeout: 5000,
        },
    };

    @node({
        id: '8d3e519f-9bf7-4ce1-9345-ab2f4c83f51a',
        name: 'Ping Local',
        type: 'n8n-nodes-base.httpRequest',
        version: 4.1,
        position: [450, 400],
    })
    PingLocal = {
        method: 'GET',
        url: 'http://127.0.0.1:5678/health',
        options: {
            timeout: 5000,
        },
    };

    @node({
        id: '57cd97c4-d8f1-473f-a185-1b96cd320b07',
        name: 'Error Check',
        type: 'n8n-nodes-base.if',
        version: 2.3,
        position: [650, 300],
    })
    ErrorCheck = {
        conditions: {
            boolean: [
                {
                    value1: '{{ $node["PingHub"].runIndex === undefined || $node["PingLocal"].runIndex === undefined }}',
                    value2: true,
                },
            ],
            options: {
                caseSensitive: true,
                typeValidation: 'strict',
            },
        },
    };

    @node({
        id: 'e06762ad-8727-4105-bd79-baf48c1203f7',
        name: 'Send Email Alert',
        type: 'n8n-nodes-base.emailSend',
        version: 2.1,
        position: [850, 300],
    })
    SendEmailAlert = {
        resource: 'email',
        operation: 'send',
        fromEmail: 'alerts@shopcomp.org',
        toEmail: '{{ $env.OWNER_EMAIL }}',
        subject: '⚠️ [SHOPCOMP] Alerta de Infraestrutura',
        message: 'Atenção: Um dos nós da federação não respondeu ao health check. Verifique a instância imediatamente.',
        emailFormat: 'text',
    };

    // =====================================================================
    // ROUTAGE ET CONNEXIONS
    // =====================================================================

    @links()
    defineRouting() {
        this.Schedule30min.out(0).to(this.PingHub.in(0));
        this.Schedule30min.out(0).to(this.PingLocal.in(0));
        this.PingHub.out(0).to(this.ErrorCheck.in(0));
        this.PingLocal.out(0).to(this.ErrorCheck.in(0));
        this.ErrorCheck.out(0).to(this.SendEmailAlert.in(0));
    }
}
