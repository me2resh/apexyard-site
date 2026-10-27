/* Each claim is checked on switch-on day.
   'live' means the claim is true today; 'coming' means it is not built yet.
   No value renders a label on the page. product.js copies the value to a
   data-claim-state attribute only.

   Switch-on checks:
   keel_versions: Keel owners and versions work on production for a Team org (an entry shows its owner and version history over MCP and on the dashboard). If not, set keel_versions to 'coming' so the line reads 'with owners' only. */
window.APEXYARD_CLAIMS = {
  gate_all_repos: 'live',   // the gate on every repository of an organisation
  named_approval: 'live',   // a named approval on every merge
  evidence_export: 'coming',  // the evidence record for each merge, and its export
  org_dashboard: 'live',    // the organisation view
  kb_mcp: 'coming',           // Keel, shared across the organisation over MCP
  keel_versions: 'live',    // Keel entries show owners and version history, over MCP and on the dashboard
  readiness_score: 'coming', // the readiness score for each repository; 'live' when it ships
  readiness_ci: 'coming',   // the audit in your own CI with your own model key; 'live' when it ships
  team_trends: 'coming',    // trends by team in the organisation view; 'live' when it ships
  ci_attestation: 'coming', // review attested by your CI; 'live' when it ships
  readiness_weekly: 'coming', // Readiness on a schedule for every repository; 'live' when it ships
  cockpit_app: 'coming'     // the Cockpit desktop app; 'live' when it ships
};
