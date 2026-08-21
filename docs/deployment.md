# Deployment

Second Breakfast deploys with [Kamal 2](https://kamal-deploy.org). There are two
destinations, `staging` and `production`, driven from GitHub Actions.

| | Staging | Production |
| --- | --- | --- |
| Trigger | Automatic, after CI passes on `main` | Manual (`workflow_dispatch`) |
| Approval | None | Required reviewer on the `production` Environment |
| Kamal config | `config/deploy.yml` + `config/deploy.staging.yml` | `config/deploy.yml` + `config/deploy.production.yml` |
| Command | `bin/kamal deploy -d staging` | `bin/kamal deploy -d production` |

## Workflows

- `.github/workflows/ci.yml` — tests (with coverage), RuboCop, Brakeman,
  importmap audit. Runs on every pull request and every push to `main`.
- `.github/workflows/deploy.yml` — the entry point. Staging fires from a
  `workflow_run` trigger on a successful CI run on `main`; production (and
  rollback) fire from `workflow_dispatch`.
- `.github/workflows/kamal.yml` — a reusable workflow holding the actual Kamal
  steps. Not triggered directly.

Staging uses `workflow_run` rather than a plain `push` trigger so that a deploy
can only happen after CI has gone green for that exact commit. Manual runs are
gated the same way: the `verify` job resolves the requested ref to a SHA and
refuses to continue unless a successful CI run exists for it.

> `workflow_run` triggers only fire for the workflow file as it exists on the
> default branch, so staging deploys will not start until this change is merged
> to `main`.

## One-time setup (repository owner)

### 1. Fill in the servers

`config/deploy.yml`, `config/deploy.staging.yml` and
`config/deploy.production.yml` still carry the Kamal scaffold placeholders
(`192.168.0.1`, `your-user`, `app.example.com`). Replace them with the real
registry user, server IPs and proxy hostnames before the first deploy.

### 2. Create the GitHub Environments

Settings → Environments → **New environment**, once for `staging` and once for
`production`.

On **production** only:

- Tick **Required reviewers** and add yourself (and anyone else who should be
  able to approve a production deploy). This is the manual approval gate — it
  cannot be set from a workflow file, only from repository settings.
- Optionally set **Deployment branches and tags** to `Selected branches` →
  `main`, so production can only ever be deployed from `main`.

### 3. Add the secrets

Add these to each Environment (Settings → Environments → *env* → Environment
secrets) so staging and production can hold different values. Repository-level
secrets work too if both environments share credentials.

| Secret | Required | What it is |
| --- | --- | --- |
| `KAMAL_REGISTRY_PASSWORD` | Yes | Access token for the container registry named under `registry:` in `config/deploy.yml`. |
| `RAILS_MASTER_KEY` | Yes | Contents of `config/master.key`. The workflow writes it back to `config/master.key` before running Kamal, because `.kamal/secrets-common` reads the key from that file. |
| `SSH_PRIVATE_KEY` | Yes | Private half of an SSH key whose public half is in `~/.ssh/authorized_keys` on every target server. Paste the whole PEM block including the header and footer lines. |
| `SSH_KNOWN_HOSTS` | Recommended | Output of `ssh-keyscan <server>` for each target host. When it is absent the workflow falls back to `StrictHostKeyChecking=accept-new` and logs a warning. |

### 4. First deploy

Kamal's `setup` step (installing Docker, booting the proxy) is not automated.
Run it once per destination from a machine with SSH access:

```sh
bin/kamal setup -d staging
bin/kamal setup -d production
```

After that, the workflows take over.

## Database migrations

Migrations are automatic. `bin/docker-entrypoint` runs `bin/rails db:prepare`
whenever a web container boots, and the Dockerfile's `CMD` ends in
`./bin/rails server`, which is the condition that hook checks. Every deploy
therefore migrates before the new container starts serving.

The deploy workflow then runs, through `kamal app exec`:

```sh
bin/rails db:migrate
bin/rails db:migrate:status
```

This is idempotent (the entrypoint has normally already applied everything) but
it makes the migration state visible in the job log and fails the deploy loudly
if a migration did not apply.

## Rolling back

A rollback re-points the proxy at a previously deployed image. It is fast and
does not rebuild anything, but **it does not roll back the database** — see the
caveat below.

### From GitHub Actions

1. Find the version you want. On a machine with SSH access:
   `bin/kamal app containers -d production` — the version is the commit SHA in
   the image tag. Past deploy runs also print the version in their job summary.
2. Actions → **Deploy** → **Run workflow**.
3. Set **environment** to `production` (or `staging`), leave **ref** alone, and
   put the SHA in **rollback_version**.
4. Approve the run when the `production` Environment asks for a reviewer.

The CI check is skipped for rollbacks, since the image being restored already
passed CI when it was built.

### From a laptop

```sh
bin/kamal app containers -d production      # list available versions
bin/kamal rollback <version> -d production  # e.g. bin/kamal rollback 0377380
```

If a deploy died mid-flight and left the lock held:

```sh
bin/kamal lock release -d production
```

### Database caveat

Rolling the application back does not undo migrations, and the older image will
run `db:prepare` against the newer schema. If the bad deploy included a
destructive migration, roll the schema back by hand first:

```sh
bin/kamal app exec -d production --reuse "bin/rails db:rollback STEP=1"
```

Prefer writing migrations that are safe to run against both the old and the new
application version (add columns before using them, drop them a deploy later)
so rollbacks stay a one-step operation.

## Local equivalents

The `Makefile` targets still work for ad-hoc operations:

| Target | Command |
| --- | --- |
| `make deploy.check` | `bin/kamal config` |
| `make deploy.setup` | `bin/kamal setup` |
| `make deploy` | `bin/kamal deploy` |

These run without a `-d` flag, i.e. against the base `config/deploy.yml` only.
Pass a destination explicitly (`bin/kamal deploy -d staging`) when you want one
of the two real environments.
