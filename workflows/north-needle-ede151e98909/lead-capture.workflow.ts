import { workflow, node, links } from '@n8n-as-code/transformer';

// <workflow-map>
// Workflow : Captura de Leads (Pioneiros)
// Nodes   : 3  |  Connections: 3
//
// NODE INDEX
// ──────────────────────────────────────────────────────────────────
// Property name                    Node type (short)         Flags
// Webhook                            webhook
// ClassifyLead                       if
// AppendToSheet                      googleSheets
//
// ROUTING MAP
// ──────────────────────────────────────────────────────────────────
// Webhook
//    → ClassifyLead
//      → AppendToSheet
//     .out(1) → AppendToSheet (↩ loop)
// </workflow-map>

// =====================================================================
// METADATA DU WORKFLOW
// =====================================================================

@workflow({
    id: '8P4rQ0R4orZs4eiT',
    name: 'Captura de Leads (Pioneiros)',
    active: false,
    isArchived: false,
    settings: { executionOrder: 'v1', callerPolicy: 'workflowsFromSameOwner', availableInMCP: false },
})
export class CapturaDeLeadsPioneirosWorkflow {
    // =====================================================================
    // CONFIGURATION DES NOEUDS
    // =====================================================================

    @node({
        id: '2676e96d-f290-4867-af2d-19dc9cbced17',
        webhookId: '32a0c10f-3bb6-4fad-98f2-53a2d9ea5917',
        name: 'Webhook',
        type: 'n8n-nodes-base.webhook',
        version: 2.1,
        position: [250, 300],
    })
    Webhook = {
        httpMethod: 'POST',
        path: 'lead-capture',
        responseMode: 'onReceived',
        responseBinaryPropertyName: 'data',
    };

    @node({
        id: '111c1f78-3cf6-4e99-91fd-6831948d0f32',
        name: 'Classify Lead',
        type: 'n8n-nodes-base.if',
        version: 2.3,
        position: [450, 300],
    })
    ClassifyLead = {
        conditions: {
            string: [
                {
                    value1: '{{ $json.body.type }}',
                    operation: 'equal',
                    value2: 'pj',
                },
            ],
            options: {
                caseSensitive: true,
                typeValidation: 'strict',
            },
        },
    };

    @node({
        id: '595f119a-02ab-403d-b13b-be111c8fbdd2',
        name: 'Append to Sheet',
        type: 'n8n-nodes-base.googleSheets',
        version: 4.4,
        position: [700, 300],
    })
    AppendToSheet = {
        resource: 'sheet',
        operation: 'append',
        documentId: '{{ $env.GOOGLE_SHEET_ID }}',
        sheetName: 'Leads',
        columns: {
            mappingMode: 'defineBelow',
            value: {
                name: '{{ $json.body.name }}',
                type: '{{ $json.body.type }}',
                email: '{{ $json.body.email }}',
            },
        },
    };

    // =====================================================================
    // ROUTAGE ET CONNEXIONS
    // =====================================================================

    @links()
    defineRouting() {
        this.Webhook.out(0).to(this.ClassifyLead.in(0));
        this.ClassifyLead.out(0).to(this.AppendToSheet.in(0));
        this.ClassifyLead.out(1).to(this.AppendToSheet.in(0));
    }
}
