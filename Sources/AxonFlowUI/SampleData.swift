import AxonFlowCore
import Foundation

public enum AxonSampleData {
    public static func demoWorkflows() -> [MacroWorkflow] {
        let emailSel = AXSelector(
            bundleID: "com.google.Chrome",
            appName: "Chrome",
            role: "AXTextField",
            identifier: "crm_lead_email",
            title: "Contact Email",
            ancestorRoles: ["AXWindow", "AXWebArea", "AXGroup"]
        )
        let planSel = AXSelector(
            bundleID: "com.google.Chrome",
            appName: "Chrome",
            role: "AXPopUpButton",
            identifier: "crm_tier_select",
            title: "Enterprise Tier",
            ancestorRoles: ["AXWindow", "AXWebArea", "AXGroup"]
        )
        let saveSel = AXSelector(
            bundleID: "com.google.Chrome",
            appName: "Chrome",
            role: "AXButton",
            subrole: "AXDefaultButton",
            identifier: "crm_submit_lead_btn",
            title: "Save & Sync Lead",
            ancestorRoles: ["AXWindow", "AXWebArea", "AXGroup"]
        )
        let mailBtn = AXSelector(
            bundleID: "com.apple.mail",
            appName: "Mail",
            role: "AXButton",
            identifier: "compose_send_btn",
            title: "Send Invoice",
            ancestorRoles: ["AXWindow", "AXToolbar"]
        )

        let wf1 = MacroWorkflow(
            name: "CRM Lead → Stripe Invoice Sync",
            summary: "Reads CSV rows, enters contact into Chrome CRM via AXIdentifier, switches to Mail, dispatches invoice.",
            steps: [
                MacroStep(order: 1, label: "Focus Chrome", action: .focusApp(bundleID: "com.google.Chrome", appName: "Chrome")),
                MacroStep(order: 2, label: "Click Contact Email", action: .click(emailSel)),
                MacroStep(order: 3, label: "Type {{email}}", action: .typeText("{{email}}")),
                MacroStep(order: 4, label: "Click Enterprise Tier", action: .click(planSel)),
                MacroStep(order: 5, label: "Click Save & Sync Lead", action: .click(saveSel)),
                MacroStep(order: 6, label: "Type {{invoice_id}} into Mail", action: .typeText("{{invoice_id}} — {{company}}")),
                MacroStep(order: 7, label: "Click Send Invoice", action: .click(mailBtn))
            ],
            variables: ["email", "invoice_id", "company"],
            rawEventCount: 52,
            hotkeyLabel: "⌥⇧1",
            runCount: 248,
            estimatedManualSecondsPerRun: 95,
            lastRunDurationMs: 1_420
        )

        let wf2 = MacroWorkflow(
            name: "PDF Receipt → Numbers Ledger",
            summary: "Extracts vendor, date, and amount into Numbers sheet rows via Accessibility tree cells.",
            steps: [
                MacroStep(order: 1, label: "Focus Numbers", action: .focusApp(bundleID: "com.apple.iWork.Numbers", appName: "Numbers")),
                MacroStep(order: 2, label: "Type {{vendor}}", action: .typeText("{{vendor}}")),
                MacroStep(order: 3, label: "Press Tab", action: .keyCombo(key: "tab", modifiers: [])),
                MacroStep(order: 4, label: "Type {{amount_usd}}", action: .typeText("{{amount_usd}}"))
            ],
            variables: ["vendor", "amount_usd"],
            rawEventCount: 31,
            hotkeyLabel: "⌥⇧2",
            runCount: 164,
            estimatedManualSecondsPerRun: 65,
            lastRunDurationMs: 840
        )

        let wf3 = MacroWorkflow(
            name: "GitHub PR → Linear Triage Card",
            summary: "Copies active PR metadata and files triaged Linear issue with milestone & owner tags.",
            steps: [
                MacroStep(order: 1, label: "Focus Linear", action: .focusApp(bundleID: "com.linear", appName: "Linear")),
                MacroStep(order: 2, label: "Press C (New Issue)", action: .keyCombo(key: "c", modifiers: [])),
                MacroStep(order: 3, label: "Type {{pr_title}}", action: .typeText("{{pr_title}}")),
                MacroStep(order: 4, label: "Press ⌘Return", action: .keyCombo(key: "return", modifiers: ["command"]))
            ],
            variables: ["pr_title"],
            rawEventCount: 24,
            hotkeyLabel: "⌥⇧3",
            runCount: 92,
            estimatedManualSecondsPerRun: 55,
            lastRunDurationMs: 610
        )

        let wf4 = MacroWorkflow(
            name: "Weekly Client KPI Export",
            summary: "Triggers dashboard CSV export, cleans columns via JXA, attaches to Slack #exec.",
            steps: [
                MacroStep(order: 1, label: "Focus Safari", action: .focusApp(bundleID: "com.apple.Safari", appName: "Safari")),
                MacroStep(order: 2, label: "Run Export AppleScript", action: .runAppleScript("tell application \"Safari\" to activate"))
            ],
            variables: ["client_slug"],
            rawEventCount: 19,
            hotkeyLabel: "⌥⇧4",
            runCount: 44,
            estimatedManualSecondsPerRun: 180,
            lastRunDurationMs: 1_950
        )

        return [wf1, wf2, wf3, wf4]
    }

    public static func demoDataset() -> CSVDataset {
        let csv = """
        email,invoice_id,company,tier
        alex@acmerobotics.io,INV-2026-8841,"Acme Robotics, Inc.",Enterprise
        sara@northstar.ai,INV-2026-8842,Northstar Labs,Enterprise
        omar@kestrelcloud.dev,INV-2026-8843,Kestrel Cloud,Pro
        nina@veloxbio.com,INV-2026-8844,Velox Bio,Enterprise
        """
        return CSVBatchEngine.parse(csv, fileName: "q4_enterprise_leads.csv")
    }

    public static func demoTraces() -> [RowExecutionTrace] {
        [
            RowExecutionTrace(rowIndex: 1, primaryLabel: "alex@acmerobotics.io", stepsExecuted: 7, strategyUsed: .identifier, durationMs: 0.42, succeeded: true),
            RowExecutionTrace(rowIndex: 2, primaryLabel: "sara@northstar.ai", stepsExecuted: 7, strategyUsed: .identifier, durationMs: 0.39, succeeded: true),
            RowExecutionTrace(rowIndex: 3, primaryLabel: "omar@kestrelcloud.dev", stepsExecuted: 7, strategyUsed: .titleAndRole, durationMs: 0.44, succeeded: true),
            RowExecutionTrace(rowIndex: 4, primaryLabel: "nina@veloxbio.com", stepsExecuted: 7, strategyUsed: .identifier, durationMs: 0.38, succeeded: true)
        ]
    }
}
