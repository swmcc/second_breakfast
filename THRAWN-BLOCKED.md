Unable to commit the completed scoped changes because the sandbox denies writes to
the worktree Git metadata at `/Users/swm/Code/second_breakfast/.git/worktrees/t3`.
`git add` fails while creating `index.lock` with `Operation not permitted`.

The Rails specs are also unable to start because the sandbox denies access to
the PostgreSQL socket at `/tmp/.s.PGSQL.5432`. Tailwind compilation, scoped
RuboCop, Ruby syntax checks, and the Brakeman scan itself completed successfully.
