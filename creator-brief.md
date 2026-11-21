# ApexYard creator brief

This brief is for people who write, film or talk about ApexYard.
It is also for AI agents that help them.
Use the facts and the wording below. Do not add claims that are not here.

## One line

Your agents write the code. Your process decides what merges.

## Short description

ApexYard gives your agents a team's process. Then it checks every pull request against that process.

## The products

| Name | Say this |
|------|----------|
<!-- feature:build -->| Build | The open-source framework. It guides your agents. |<!-- /feature:build -->
<!-- feature:gate -->| Gate | Checks each pull request against your process. |<!-- /feature:gate -->
<!-- feature:readiness -->| Readiness | Measures each repository. |<!-- /feature:readiness -->
| Keel | Your team's rules and context, read by every agent. |

## The idea to explain

You write a rule one time. <!-- feature:build -->Build guides your agents with it.<!-- /feature:build --> <!-- feature:gate -->Gate checks each pull request against it.<!-- /feature:gate --> <!-- feature:readiness -->Readiness measures the whole repository.<!-- /feature:readiness --> A miss becomes a new rule.

Example rule: "Every API endpoint checks who is calling." Your team adds it to its handbook, marked blocking.

## Facts you can state

<!-- feature:build -->- Build is open source under the MIT licence.<!-- /feature:build -->
<!-- feature:build -->- Build needs no account and no dashboard.<!-- /feature:build -->
<!-- feature:build -->- Build works with Claude Code, Codex, Cursor, OpenCode, Pi and omp.<!-- /feature:build -->
<!-- feature:build -->- Build runs on the developer's machine.<!-- /feature:build -->
<!-- feature:gate -->- Gate checks each pull request on GitHub.<!-- /feature:gate -->
<!-- feature:gate -->- Gate checks for a ticket, a decision record, a review and a named approval.<!-- /feature:gate -->
<!-- feature:gate -->- Our servers never fetch your code. The Gate GitHub App has no Contents permission. It sees pull request titles, descriptions and changed file names, not the files.<!-- /feature:gate -->
<!-- feature:gate -->- Gate blocks a merge only when the team makes the check required in GitHub.<!-- /feature:gate -->
<!-- feature:readiness -->- Readiness gives a go or no-go for a repository, the gaps in each area and the top actions.<!-- /feature:readiness -->
<!-- feature:readiness -->- Readiness covers ten areas, from security to documentation.<!-- /feature:readiness -->

## Facts you must not state

<!-- feature:pricing -->- Do not state a price, a discount or an offer. Send people to https://apexyard.ai/pricing.<!-- /feature:pricing -->
- Do not describe plan limits or plan details.
- Do not say that a feature exists if the product pages do not say so.
- Do not say that ApexYard replaces human review. A person approves each merge.
- Do not call the pages or the examples on the site real customer data. The examples use fictional names.

## Who it is for

<!-- feature:build -->- Founders and engineering leads who want agent speed and a real process (Build).<!-- /feature:build -->
<!-- feature:gate -->- Engineering leads whose teams merge code that agents wrote (Gate).<!-- /feature:gate -->
<!-- feature:readiness -->- CTOs and engineering leads who answer for what ships (Readiness).<!-- /feature:readiness -->

## Links

- Home: https://apexyard.ai/
<!-- feature:build -->- Build: https://apexyard.ai/build<!-- /feature:build -->
<!-- feature:gate -->- Gate: https://apexyard.ai/gate<!-- /feature:gate -->
<!-- feature:readiness -->- Readiness: https://apexyard.ai/readiness<!-- /feature:readiness -->
<!-- feature:pricing -->- Pricing: https://apexyard.ai/pricing<!-- /feature:pricing -->
- Docs: https://apexyard.ai/docs
- Source: https://github.com/me2resh/apexyard
- Site summary for agents: https://apexyard.ai/llms.txt

## Wording rules

- Use short sentences.
<!-- feature-all:gate readiness -->- Name the product: Build, Gate, Readiness or Keel.
<!-- /feature-all:gate readiness -->
<!-- feature-off:gate readiness -->- Name only the products shown on the site.
<!-- /feature-off:gate readiness -->
- Say "pull request", not "PR", on first use.
