# Local git hooks

Block a commit message, or an outgoing commit message, that holds a private term.

Install in a clone or worktree: `git config core.hooksPath .githooks`

The hooks read terms from `~/.claude/apexyard/private/private-terms.txt`, one per line. Without that file they skip silently. They print the field and the term index only.
