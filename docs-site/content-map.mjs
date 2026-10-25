// Content map for the /docs section.
//
// This file maps source files in me2resh/apexyard (at the pinned tag) to docs
// pages. It holds structure only: slugs, titles, group sentences and source
// paths. Page text comes from the source repository at build time.
//
// Part shapes:
//   { source: 'path.md' }                       whole file, first H1 removed
//   { source: 'path.md', sections: ['Heading'] } only the named sections
//   { source: 'path', code: 'yaml' }            file shown as one code block
//   { source: 'bin/x', heredoc: 'usage' }       first heredoc of a shell function
//
// A page with `coming` has no source yet. It renders a Coming callout.

export const SOURCE = {
  repo: 'me2resh/apexyard',
  url: 'https://github.com/me2resh/apexyard',
  tag: 'v5.10.1',
  // The commit the tag points to. The sync step stops when the tag moves.
  commit: 'fa6911078bb3c91af457290cd2c7e8bd91843746',
  // Edit links point at the default development branch.
  editBranch: 'dev',
};

// Source paths that never become a page. The sync step fails when a page in
// this map, or a generated page, reads a file under one of these prefixes.
export const EXCLUDED_PREFIXES = [
  { prefix: 'docs/spike', reason: 'Spike notes and spike output (internal research)' },
  { prefix: 'docs/spike-reports/', reason: 'Spike reports (internal research)' },
  { prefix: 'docs/spike-memos/', reason: 'Spike memos (internal research)' },
  { prefix: 'docs/prds/', reason: 'Product requirement drafts (internal planning)' },
  { prefix: 'docs/technical-designs/', reason: 'Technical designs (internal planning)' },
  { prefix: 'docs/designs/', reason: 'Design documents (internal planning)' },
  { prefix: 'docs/perf/', reason: 'Performance and cost measurements (internal)' },
  { prefix: 'docs/quality-regression/', reason: 'Quality regression fixtures (internal tests)' },
  { prefix: 'docs/eval-agents/', reason: 'Review-agent evaluation corpus and reports (internal tests)' },
  { prefix: 'docs/agdr/', reason: 'Agent Decision Records (decision history, linked on GitHub instead)' },
  { prefix: 'docs/orbit/', reason: 'ORBIT planning records of the framework (internal planning)' },
  { prefix: 'docs/agents/', reason: 'Maintainer notes for review-agent prompts (internal)' },
  { prefix: 'docs/skills/', reason: 'Maintainer rationale for skill internals (internal)' },
  { prefix: 'docs/release-process.md', reason: 'Framework release steps for maintainers (internal)' },
  { prefix: 'docs/orchestrator-cost-model.md', reason: 'Model cost notes (internal)' },
  { prefix: 'docs/local-model-setup.md', reason: 'Local model routing experiment (internal)' },
  { prefix: 'marketplace/', reason: 'Duplicate copies of audit skills for the plugin marketplace' },
];

const learn = [
  {
    id: 'quickstart',
    title: 'Quickstart',
    icon: 'rocket',
    summary: 'Learn what ApexYard is, install it, and open your first governed pull request.',
    pages: [
      {
        slug: 'quickstart/what-is-apexyard',
        title: 'What ApexYard is',
        description: 'One set of rules, used twice: by your agents while they work, and by the gate before a merge.',
        parts: [{ source: 'README.md', sections: ['AI can build quickly. Shipping safely needs a system.', 'What makes it different', "What's inside"] }],
      },
      {
        slug: 'quickstart/key-concepts',
        title: 'Key concepts',
        description: 'Roles, skills, gates, and the loop that connects them.',
        parts: [{ source: 'docs/onboarding/capability-tour.md' }],
      },
      {
        slug: 'quickstart/install',
        title: 'Install',
        description: 'Fork the framework, configure it, and register your projects.',
        callouts: [
          {
            type: 'coming',
            text: 'A one-command installer, `apexyard init`, is not in release {tag}. Until a release includes it, fork the repository as this page shows.',
          },
        ],
        parts: [{ source: 'README.md', sections: ['Quick Start — fork and go'], skip: ['6. Start working', 'Optional: status band above the prompt'] }],
      },
      {
        slug: 'quickstart/first-governed-pr',
        title: 'Your first governed PR',
        description: 'Start work on a ticket and let the roles and gates guide it to a merge.',
        parts: [
          { source: 'README.md', sections: ['6. Start working'] },
          { source: 'docs/getting-started.md', sections: ['Step 4: Start Using It'] },
        ],
      },
      {
        slug: 'quickstart/glossary',
        title: 'Glossary',
        description: 'Plain-language meanings for the terms the framework uses.',
        parts: [{ source: 'docs/onboarding/glossary.md' }],
      },
    ],
  },
  {
    id: 'day-to-day',
    title: 'Working day to day',
    icon: 'approve-check-circle',
    summary: 'Move one ticket from branch to merge, with reviews, approvals, status and planning.',
    pages: [
      {
        slug: 'day-to-day/tickets',
        title: 'Tickets',
        description: 'Work on one ticket at a time, and declare it before you edit code.',
        parts: [{ source: '.claude/rules/workflow-gates.md', sections: ['One Ticket at a Time', 'Pre-Build Gate'] }],
      },
      {
        slug: 'day-to-day/branches-and-worktrees',
        title: 'Branches and worktrees',
        description: 'Name branches, PR titles and commits, and choose how builds are isolated.',
        parts: [
          { source: '.claude/rules/git-conventions.md', sections: ['Branch Naming', 'PR Title Format', 'Commit Message Format'] },
          { source: 'docs/project-config.md', sections: ['Build isolation (`build.isolation`)'] },
        ],
      },
      {
        slug: 'day-to-day/rex-reviews',
        title: 'Rex reviews',
        description: 'How the code reviewer checks each pull request, and what the author does.',
        parts: [{ source: 'workflows/code-review.md' }],
      },
      {
        slug: 'day-to-day/approvals-and-merge',
        title: 'Approvals and merge',
        description: 'The checks before a merge, and the named human approval for each pull request.',
        parts: [{ source: '.claude/rules/pr-workflow.md', sections: ['Before `gh pr merge` (HARD STOP)', 'After Pushing Commits to an Open PR'] }],
      },
      {
        slug: 'day-to-day/status',
        title: 'Status',
        description: 'See what waits for you and where each project stands.',
        parts: [{ source: 'docs/multi-project.md', sections: ['Daily workflow'] }],
      },
      {
        slug: 'day-to-day/orbit-planning',
        title: 'ORBIT planning',
        description: 'Plan an initiative in slices, one ticket and one pull request for each slice.',
        parts: [{ source: 'docs/orbit-adapter.md' }],
      },
    ],
  },
  {
    id: 'your-rules',
    title: 'Your rules',
    icon: 'pencil',
    summary: 'Write your own coding standards and turn review findings into rules.',
    pages: [
      {
        slug: 'your-rules/handbooks',
        title: 'Handbooks',
        description: 'Coding standards that Rex reads during each review.',
        parts: [{ source: 'handbooks/README.md' }],
      },
      {
        slug: 'your-rules/rules',
        title: 'Rules',
        description: 'Every framework rule, where it is written, and what enforces it.',
        parts: [{ source: 'docs/rule-audit.md' }],
      },
      {
        slug: 'your-rules/codify-rule',
        title: 'Turn a finding into a rule',
        description: 'Use /codify-rule to make a handbook entry from a review comment.',
        parts: [{ source: '.claude/skills/codify-rule/SKILL.md' }],
      },
      {
        slug: 'your-rules/knowledge-base',
        title: 'The knowledge base',
        description: 'Searchable rule indexes generated from your handbooks.',
        coming: {
          text: 'The knowledge base is not in release {tag}. This page gets its content when a release includes it.',
        },
      },
    ],
  },
  {
    id: 'roles-and-agents',
    title: 'Roles and agents',
    icon: 'puzzle',
    summary: 'The roles that activate on triggers, the reviewer agents, and the coding tools you can use.',
    pages: [
      {
        slug: 'roles-and-agents/roles',
        title: 'Roles',
        description: 'Twenty roles in six departments, each with clear limits.',
        parts: [{ source: 'docs/whats-inside.md', sections: ['Roles'] }],
      },
      {
        slug: 'roles-and-agents/reviewer-agents',
        title: 'Reviewer agents',
        description: 'Rex, Hakim, Tariq and Naqid, and the department agents.',
        parts: [
          { source: 'docs/whats-inside.md', sections: ['The 23 sub-agents'] },
          { source: 'workflows/code-review.md', sections: ['Approval Requirements'] },
        ],
      },
      {
        slug: 'roles-and-agents/agent-tools',
        title: 'Agent tools',
        description: 'Which coding tools ApexYard supports, and how one core serves them all.',
        parts: [{ source: 'docs/harnesses/README.md' }],
      },
      { slug: 'roles-and-agents/claude-code', title: 'Claude Code', description: 'Use ApexYard with Claude Code.', parts: [{ source: 'docs/harnesses/claude-code.md' }] },
      { slug: 'roles-and-agents/codex', title: 'Codex', description: 'Use ApexYard with Codex.', parts: [{ source: 'docs/harnesses/codex.md' }] },
      { slug: 'roles-and-agents/cursor', title: 'Cursor', description: 'Use ApexYard with Cursor.', parts: [{ source: 'docs/harnesses/cursor.md' }] },
      { slug: 'roles-and-agents/opencode', title: 'OpenCode', description: 'Use ApexYard with OpenCode.', parts: [{ source: 'docs/harnesses/opencode.md' }] },
      { slug: 'roles-and-agents/pi', title: 'Pi', description: 'Use ApexYard with Pi.', parts: [{ source: 'docs/harnesses/pi.md' }] },
    ],
  },
  {
    id: 'hosted-gate',
    title: 'The hosted gate',
    icon: 'github',
    summary: 'Install the GitHub App, read the check, and find the approval record for each merge.',
    pages: [
      {
        slug: 'hosted-gate/github-app',
        title: 'The GitHub App',
        description: 'Install the app on the repositories that the gate protects.',
        coming: { text: 'User guides for the hosted gate are coming. This page gets its content when the guide is published.' },
      },
      {
        slug: 'hosted-gate/the-check',
        title: 'The check',
        description: 'Read the status check that the gate adds to each pull request.',
        coming: { text: 'User guides for the hosted gate are coming. This page gets its content when the guide is published.' },
        figure: { src: 'img/placeholder-check.svg', alt: 'Placeholder for a screenshot of the gate check on a pull request', width: 1200, height: 675 },
      },
      {
        slug: 'hosted-gate/dashboard',
        title: 'The dashboard',
        description: 'See open pull requests and the approvals they wait for.',
        coming: { text: 'User guides for the hosted gate are coming. This page gets its content when the guide is published.' },
        figure: { src: 'img/placeholder-dashboard.svg', alt: 'Placeholder for a screenshot of the hosted dashboard', width: 1200, height: 675 },
      },
      {
        slug: 'hosted-gate/evidence-record',
        title: 'The evidence record',
        description: 'Find who approved a merge, when, and at which commit.',
        coming: { text: 'User guides for the hosted gate are coming. This page gets its content when the guide is published.' },
      },
      {
        slug: 'hosted-gate/agent-sign-in',
        title: 'Agent sign-in over MCP',
        description: 'Connect a coding agent to the gate with your own sign-in.',
        coming: { text: 'User guides for the hosted gate are coming. This page gets its content when the guide is published.' },
      },
    ],
  },
  {
    id: 'portfolio',
    title: 'Portfolio',
    icon: 'list-format',
    summary: 'Run many projects from one ops repository, in one shared or split layout.',
    pages: [
      {
        slug: 'portfolio/multi-project',
        title: 'Multi-project setup',
        description: 'Fork once and manage every project from that fork.',
        parts: [{ source: 'docs/multi-project.md', sections: ['Two setup modes — pick the one that matches your privacy needs', 'TL;DR — single-fork mode (default)', 'Why fork instead of clone?', 'Setup — six steps, about five minutes'] }],
      },
      {
        slug: 'portfolio/registry',
        title: 'The registry',
        description: 'The file that lists each project under management.',
        parts: [
          { source: 'docs/multi-project.md', sections: ['5. Create the registry'] },
          { source: 'apexyard.projects.yaml.example', code: 'yaml', heading: 'Example registry' },
        ],
      },
      {
        slug: 'portfolio/split-portfolio',
        title: 'Split portfolio',
        description: 'Keep the framework public and your portfolio data private.',
        parts: [{ source: 'docs/multi-project.md', sections: ['Split-portfolio mode — public framework + private portfolio'] }],
      },
    ],
  },
  {
    id: 'updating',
    title: 'Updating',
    icon: 'cloud-download',
    summary: 'Bring new framework releases into your fork without losing your changes.',
    pages: [
      {
        slug: 'updating/update',
        title: 'Update your fork',
        description: 'Run /update to sync your fork with a new release.',
        parts: [{ source: 'docs/upgrading.md', sections: ['TL;DR', 'The version anchor', 'Common scenarios', "When `/update` isn't enough — re-forking & keeping your data"] }],
      },
      {
        slug: 'updating/migrations',
        title: 'Migrations',
        description: 'The per-release steps that /update runs in order.',
        parts: [{ source: 'docs/upgrading.md', sections: ['What each migration does'] }],
      },
      {
        slug: 'updating/drift-safe-updates',
        title: 'Drift-safe updates',
        description: 'An ownership manifest that tells framework files from your own files.',
        coming: {
          text: 'The ownership manifest and the path-ownership check are not in release {tag}. This page gets its content when a release includes them.',
        },
      },
      {
        slug: 'updating/project-versions',
        title: 'Version your projects',
        description: 'Version and release the projects that you manage.',
        parts: [{ source: 'docs/managed-project-versioning.md' }],
      },
    ],
  },
  {
    id: 'how-to',
    title: 'How-to guides',
    icon: 'open-book',
    summary: 'Step-by-step guides for one task each.',
    pages: [
      {
        slug: 'how-to/reviewer-github-app',
        title: 'Use a GitHub App for agent reviews',
        description: 'Post agent reviews as an app, not as your own account.',
        parts: [{ source: 'docs/how-to/reviewer-github-app.md' }],
      },
    ],
  },
  {
    id: 'security',
    title: 'Security',
    icon: 'warning',
    summary: 'How the gates fail closed, what you can bypass, and how to report a problem.',
    pages: [
      {
        slug: 'security/hooks-fail-closed',
        title: 'Hooks fail closed',
        description: 'A gate that cannot decide blocks the action.',
        parts: [{ source: 'docs/hooks-fail-closed.md', sections: ['Terms', 'What fails closed', 'Minimum Claude Code version for `onFailure`', 'Review agent detection needs `agent_type`', 'Plugin marketplace validation'] }],
      },
      {
        slug: 'security/bypass',
        title: 'What you can and cannot bypass',
        description: 'The operator escape hatch, and the limits of the hooks.',
        parts: [
          { source: 'docs/hooks-fail-closed.md', sections: ['Operator escape hatch'] },
          { source: 'SECURITY.md', sections: ['Threat model'] },
        ],
      },
      {
        slug: 'security/policy',
        title: 'Security policy',
        description: 'Supported versions, scope, and the scans the project runs.',
        parts: [{ source: 'SECURITY.md', sections: ['Supported versions', 'Scope', 'Our own scanning'] }],
      },
      {
        slug: 'security/reporting',
        title: 'Report a vulnerability',
        description: 'Tell the maintainers about a security problem in private.',
        parts: [{ source: 'SECURITY.md', sections: ['Reporting a vulnerability'] }],
      },
    ],
  },
  {
    id: 'readiness',
    title: 'Readiness',
    icon: 'information',
    summary: 'Check that a project is ready for production, and fix the gaps first.',
    pages: [
      {
        slug: 'readiness/overview',
        title: 'What Readiness checks',
        description: 'The 10 dimensions that /launch-check checks before a release.',
        parts: [
          {
            text: [
              'Readiness tells you if a project is ready for production.',
              '[`/launch-check`](/docs/reference/skills/launch-check) checks 10 dimensions in one sweep and gives one verdict.',
              'The table below lists the 10 dimensions. For each one, it names the skill for a deeper audit.',
              'For example, the threat model is the deeper audit for Security, and mutation testing is the deeper audit for behaviour quality.',
              '',
              '`/security-review` is different. It reviews the security of one pull request, not a whole project.',
            ].join('\n'),
          },
          { source: '.claude/skills/launch-check/SKILL.md', sections: ['Deep-dive companions'] },
        ],
        callouts: [
          {
            type: 'coming',
            text: 'Readiness in CI, the hosted score and the hosted trend are not built yet. Today you run the audits with the skills on this page.',
          },
        ],
      },
      {
        slug: 'readiness/run-the-audits',
        title: 'Run the audits today',
        description: 'Run each readiness audit with a skill that ships in the framework.',
        parts: [
          {
            text: [
              'Run `/launch-check` first. It checks all 10 dimensions quickly and gives one verdict.',
              'Then run the deeper skill for each dimension that shows a warning or a failure.',
            ].join('\n'),
          },
          {
            skillList: ['launch-check', 'threat-model', 'accessibility-audit', 'compliance-check', 'analytics-audit', 'seo-audit', 'geo-audit', 'performance-audit', 'monitoring-audit', 'docs-audit', 'mutation-test'],
          },
        ],
      },
      {
        slug: 'readiness/score',
        title: 'The readiness score',
        description: 'How /launch-check computes its score today, and the verdict: go or no-go.',
        parts: [
          {
            text: [
              '`/launch-check` gives each dimension a score from 0 to 100.',
              'The headline score of a run is the unweighted mean of the dimension scores in that run, rounded to a whole number.',
              'A run with no dimension scores has a headline score of 0.',
              'The trend chart uses the same rule ([`render-trend.sh`](https://github.com/me2resh/apexyard/blob/{tag}/.claude/skills/launch-check/render-trend.sh)).',
              '',
              'The verdict does not come from the score. It comes from the PASS, WARN and FAIL results and any critical security finding, as the table below shows.',
            ].join('\n'),
          },
          { source: '.claude/skills/launch-check/SKILL.md', sections: ['Verdict logic', '6a. Resolve project name + score + verdict'] },
        ],
        callouts: [
          {
            type: 'coming',
            text: 'The hosted Production-Ready Score and its hosted trend are not built yet. Their formula is not published. Until then, use the `/launch-check` score on this page.',
          },
        ],
      },
      {
        slug: 'readiness/top-actions',
        title: 'Top actions',
        description: 'Fix the blocking items first, then the warnings.',
        parts: [
          {
            text: [
              'The audit output lists the top actions in two groups:',
              '',
              '1. Blocking items. Fix these before you release.',
              '2. Warnings. Fix these before the next milestone.',
            ].join('\n'),
          },
          { source: '.claude/skills/launch-check/SKILL.md', sections: ['Output format', 'Step 4: Compile the verdict', 'Step 5: Output'] },
        ],
      },
      {
        slug: 'readiness/privacy',
        title: 'Privacy',
        description: 'Where the audits run and where the results go.',
        parts: [
          {
            text: [
              'Today the audit skills run where your coding agent runs, with your own model access.',
              'Each `/launch-check` run is saved in your projects folder. By default that is `projects/<name>/audits/` in your ops repository.',
            ].join('\n'),
          },
        ],
        callouts: [
          {
            type: 'coming',
            text: [
              'Readiness in CI is not built yet. When it ships:',
              '',
              '- It runs in your CI with your own model key.',
              '- Only the results go to the hosted service.',
              '- No code goes to ApexYard. Your model provider receives only what your own key sends.',
            ].join('\n'),
          },
        ],
      },
    ],
  },
];

// Reference groups. A group with `generate` gets its pages from the source tree.
const reference = [
  {
    id: 'skills',
    title: 'Skills',
    icon: 'forward-slash',
    summary: 'One page for each slash command, from its own definition.',
    generate: 'skills',
    collapsed: true,
  },
  {
    id: 'hooks',
    title: 'Hooks',
    icon: 'approve-check',
    summary: 'The shell checks that run on each edit, commit, push and merge.',
    collapsed: true,
    pages: [
      { slug: 'reference/hooks/overview', title: 'How the hooks fit together', description: 'Where the hooks run and how they share state.', parts: [{ source: '.claude/hooks/README.md', sections: ['How It Fits Together', 'Settings Ordering Note', 'Session State Directory', 'Dependencies'] }] },
      { slug: 'reference/hooks/enforcement-layer', title: 'The enforcement layer', description: 'Ticket-first edits, auto review, the merge gate and the drift banner.', parts: [{ source: '.claude/hooks/README.md', sections: ['The Enforcement Layer'] }] },
      { slug: 'reference/hooks/vocabulary-backstops', title: 'Ticket-vocabulary backstops', description: 'Checks that each issue reference names a real issue.', parts: [{ source: '.claude/hooks/README.md', sections: ['The Ticket-Vocabulary Backstops'] }] },
      { slug: 'reference/hooks/rule-hooks', title: 'Rule hooks', description: 'Hooks that turn written rules into checks.', parts: [{ source: '.claude/hooks/README.md', sections: ['The Rule-Mechanization Hooks (GH-13)', 'PWD-vs-command-context distinction'] }] },
      { slug: 'reference/hooks/other-hooks', title: 'Other hooks', description: 'Hooks that came before the enforcement layer.', parts: [{ source: '.claude/hooks/README.md', sections: ['Pre-existing Hooks'] }] },
      { slug: 'reference/hooks/testing', title: 'Test and add a hook', description: 'Run a hook by hand, and add a new one.', parts: [{ source: '.claude/hooks/README.md', sections: ['Testing a Hook', 'Adding a New Hook'] }] },
      { slug: 'reference/hooks/hook-index', title: 'Hook index', description: 'Every hook script, with the first line of its header.', generate: 'hook-index' },
    ],
  },
  {
    id: 'rules',
    title: 'Rules',
    icon: 'document',
    summary: 'The rule files that agents load when the work matches.',
    generate: 'rules',
    collapsed: true,
  },
  {
    id: 'roles',
    title: 'Roles',
    icon: 'star',
    summary: 'Each role file: identity, limits, interfaces and handoffs.',
    generate: 'roles',
    collapsed: true,
  },
  {
    id: 'cli',
    title: 'CLI',
    icon: 'laptop',
    summary: 'The apexyard command and its subcommands.',
    pages: [
      {
        slug: 'reference/cli',
        title: 'The apexyard command',
        description: 'Run environment checks and a status briefing from the terminal.',
        parts: [
          { source: 'bin/apexyard', heredoc: 'usage', heading: 'Usage' },
          { source: 'docs/multi-project.md', sections: ['`apexyard status` — the CLI briefing'] },
        ],
      },
    ],
  },
  {
    id: 'configuration',
    title: 'Configuration',
    icon: 'setting',
    summary: 'Project-config keys and the onboarding file.',
    pages: [
      { slug: 'reference/configuration/project-config', title: 'Project config', description: 'Every key in .claude/project-config.json.', parts: [{ source: 'docs/project-config.md' }] },
      { slug: 'reference/configuration/onboarding', title: 'onboarding.yaml', description: 'The company configuration file that /setup writes.', parts: [{ source: 'onboarding.example.yaml', code: 'yaml', heading: 'Example file' }] },
    ],
  },
  {
    id: 'golden-paths',
    title: 'Golden paths',
    icon: 'add-document',
    summary: 'CI pipelines and topology bundles to copy into a project.',
    pages: [
      { slug: 'reference/golden-paths/pipelines', title: 'CI pipelines', description: 'Reusable GitHub Actions workflows.', parts: [{ source: 'golden-paths/pipelines/README.md' }] },
      { slug: 'reference/golden-paths/topologies', title: 'Topologies', description: 'Handbooks, pipelines and templates for one service shape.', parts: [{ source: 'topologies/README.md' }] },
    ],
  },
  {
    id: 'adapters',
    title: 'Adapters',
    icon: 'puzzle',
    summary: 'How each coding tool gets the same rules and gates.',
    pages: [
      { slug: 'reference/adapters/codex', title: 'Codex adapter', description: 'Generate the Codex surface from .claude/.', parts: [{ source: 'docs/codex-adapter.md' }] },
      { slug: 'reference/adapters/cursor', title: 'Cursor adapter', description: 'Install the Cursor adapter.', parts: [{ source: 'docs/cursor-adapter.md' }] },
      { slug: 'reference/adapters/opencode', title: 'OpenCode adapter', description: 'Install the OpenCode adapter.', parts: [{ source: 'docs/opencode-adapter.md' }] },
      { slug: 'reference/adapters/portfolio', title: 'Portfolio adapters', description: 'Choose the adapters each managed project receives.', parts: [{ source: 'docs/harnesses/portfolio-adapters.md' }] },
      { slug: 'reference/adapters/conformance-ci', title: 'Conformance CI', description: 'The live proof that each adapter runs the gates.', parts: [{ source: 'docs/conformance-ci.md' }] },
    ],
  },
  {
    id: 'changelog',
    title: 'Changelog',
    icon: 'comment-alt',
    summary: 'What changed in each recent release.',
    generate: 'changelog',
    releases: 6,
  },
];

export const SECTIONS = [
  { id: 'learn', title: 'Learn', summary: 'Guides that explain how to work with ApexYard.', groups: learn },
  { id: 'reference', title: 'Reference', summary: 'Facts to look up: every skill, hook, rule, role and setting.', groups: reference },
];

// Generic words that mark text about paid components or prices. A page whose
// text matches is excluded. Keep only generic terms here: this repo is public.
// Private repository names and offer names come from the file in
// DOCS_PRIVATE_TERMS (one term per line). That file stays outside this repo.
export const DENY_TERMS = [
  '\\bpremium\\b',
  '\\bpaid (?:tier|plan|component|feature)s?\\b',
  '\\bpric(?:e|es|ing)\\b',
];

// Pages that use a deny term in a generic sense. Each entry states why.
export const DENY_ALLOW = {
  'reference/skills/analytics-audit': 'Names a pricing page as an example funnel step in the audited product.',
  'reference/skills/launch-check': 'Names a pricing page of the audited product as an example finding.',
  'readiness/top-actions': 'Shows the /launch-check example output, which names a pricing page of the audited product.',
  'reference/skills/seo-audit': 'Names a pricing page of the audited product as an example page to check.',
  'reference/roles/product-product-analyst': 'Lists competitor pricing as a market-research topic.',
  'reference/skills/setup': 'Names the GitHub paid plan that allows private forks.',
  'reference/rules/evidence-grounding': 'Lists prices as an example of state that can change.',
};
