/* Team claims on the product pages (#102).
   Each claim is live on the day the site switches on. To show a claim as
   "Coming" instead, change its value to 'coming'. One line per claim; no
   copy changes are needed. product.js reads this object. */
window.APEXYARD_CLAIMS = {
  gate_all_repos: 'live',   // the gate on every repository of an organisation
  named_approval: 'live',   // a named approval on every merge
  evidence_export: 'live',  // the evidence record for each merge, and its export
  org_dashboard: 'live',    // the organisation view with trends
  kb_mcp: 'live',           // the shared knowledge base over MCP
  readiness_score: 'coming', // the readiness score for each repository; 'live' when it ships
  readiness_ci: 'coming',   // the audit in your own CI with your own model key; 'live' when it ships
  team_trends: 'coming',    // trends by team in the organisation view; 'live' when it ships
  ci_attestation: 'coming', // review attested by your CI; 'live' when it ships
  readiness_weekly: 'coming', // Readiness on a schedule for every repository; 'live' when it ships
  cockpit_app: 'coming'     // the Cockpit desktop app; 'live' when it ships
};
