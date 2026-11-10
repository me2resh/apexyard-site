/* Each claim is checked on switch-on day.
   'live' means the claim is true today; 'coming' means it is not built yet.
   product.js copies the value to a data-claim-state attribute only.

   APEXYARD_LABELS holds the one label that each claim carries on the page
   (#160). The pages print the label as static text, so a visitor without
   scripts sees it too. .github/tests/test-claims.sh fails when a page label
   differs from the text here. A 'live' claim reads 'Available now' or
   'Early teams (by hand)'. A 'coming' claim reads 'Planned', with its
   date when the cloud plan (revision 10, 10 Nov 2026) holds one, or
   'Preview'. Never write a date that the plan does not hold.

   Switch-on checks:
   kb_mcp: Keel owners and versions work on production for a Team org (an entry shows its owner and version history over MCP and on the dashboard). The label also covers the words 'with owners and versions' on the pricing page. */
window.APEXYARD_CLAIMS = {
  gate_all_repos: 'live',   // the gate on every repository of an organisation
  named_approval: 'live',   // a named approval on every merge
  evidence_export: 'coming',  // the evidence record for each merge, and its export
  org_dashboard: 'live',    // the organisation view
  kb_mcp: 'coming',           // Keel, shared across the organisation over MCP, with owners and versions; the knowledge base flag is off in production until 18 Jan 2027
  readiness_score: 'coming', // the readiness score for each repository; 'live' when it ships
  readiness_ci: 'coming',   // the audit in your own CI with your own model key; 'live' when it ships
  team_trends: 'coming',    // trends by team in the organisation view; 'live' when it ships
  ci_attestation: 'coming', // review attested by your CI; 'live' when it ships
  readiness_weekly: 'coming', // Readiness on a schedule for every repository; 'live' when it ships
  cockpit_app: 'coming',    // the Cockpit desktop app; 'live' when it can be downloaded
  cockpit_signin: 'coming', // sign in to the Cockpit with GitHub through ApexYard; 'live' when it ships
  free_checks: 'coming',    // the free hosted check on public repositories; 'live' when the free tier opens
  paid_plans: 'coming'      // plans that open by card, with evidence retention; 'live' when they open
};

window.APEXYARD_LABELS = {
  gate_all_repos: 'Early teams (by hand)',
  named_approval: 'Early teams (by hand)',
  evidence_export: 'Planned',
  org_dashboard: 'Early teams (by hand)',
  kb_mcp: 'Planned for 18 Jan 2027',
  readiness_score: 'Planned for 4 Dec 2026',
  readiness_ci: 'Planned for 1 Mar 2027',
  team_trends: 'Planned',
  ci_attestation: 'Planned',
  readiness_weekly: 'Planned for 1 Mar 2027',
  cockpit_app: 'Preview',
  cockpit_signin: 'Planned',
  free_checks: 'Planned for 1 Feb 2027',
  paid_plans: 'Planned for 1 Mar 2027'
};
