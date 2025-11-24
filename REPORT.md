# Audit Report — swmcc/second_breakfast
Date: 2025-11-24
Branch: audit/second_breakfast-20251124

## Executive summary
The repository is generally healthy but needs improved automation for security and quality checks, better documentation for onboarding, and a few low-to-medium security hardening changes. This report includes automation-friendly patches and commands so an assistant or bot can apply fixes.

## Overall risk / priority score
Medium — most issues are medium/low effort and can be remedied with CI automation and small code/config changes.

## Findings (by category)

### Security

1) Secrets in repo / .env handling
- Severity: High
- Description: Confirm `.env` and other secret files are not committed and are ignored. Add `.env.local` and `.env.*` patterns to `.gitignore`.
- Location: repository root
- Suggested fix (patch):

--- a/.gitignore
+++ b/.gitignore
@@ -1,3 +1,6 @@
+# ignore dotenv files
+.env
+.env.*
 
 # Ignore bundler config
 /.bundle

- Apply with:
- ```bash
- git checkout -b chore/audit-gitignore
- git apply --directory=. <<'PATCH'
- *** Begin Patch
- *** Update File: .gitignore
- @@
- +# ignore dotenv files
- +.env
- +.env.*
- *** End Patch
- PATCH
- ```
+Apply with:
+
+```bash
+git checkout -b chore/audit-gitignore
+cat >> .gitignore <<'EOF'
+# ignore dotenv files
+.env
+.env.*
+EOF
+git add .gitignore && git commit -m "chore: gitignore dotenv files" && git push origin chore/audit-gitignore
+```

2) Brakeman automation
- Severity: Medium
- Description: Brakeman is available via `make local.brakeman` but not enforced in CI. Add a GitHub Actions job to run Brakeman on PRs and fail on high confidence findings.
- Suggested workflow (file: .github/workflows/security.yml):

```yaml
name: Security
on: [pull_request]
jobs:
  brakeman:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
      - run: bundle install --jobs 4 --retry 3
      - run: bundle exec brakeman -A -o brakeman-output.json || true
      - name: Upload Brakeman results
        uses: actions/upload-artifact@v4
        with:
          name: brakeman
          path: brakeman-output.json
      - name: Fail on High Confidence Findings
        run: |
          jq '.warnings[] | select(.confidence=="High")' brakeman-output.json | wc -l | grep -q "^0$"
```

- Apply with: create the workflow file at `.github/workflows/security.yml` and push to audit branch.

### Dependencies

1) Dependabot not configured
- Severity: Medium
- Description: Add Dependabot to automate Ruby gem updates and GitHub Actions checker.
- Suggested config (`.github/dependabot.yml`):

```yaml
version: 2
updates:
  - package-ecosystem: "bundler"
    directory: "/"
    schedule:
      interval: "daily"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

- Apply with:

```bash
git checkout -b chore/add-dependabot
cat > .github/dependabot.yml <<'YML'
version: 2
updates:
  - package-ecosystem: "bundler"
    directory: "/"
    schedule:
      interval: "daily"
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
YML
git add .github/dependabot.yml && git commit -m "chore: add dependabot config" && git push origin chore/add-dependabot
```

### Code Quality

1) RuboCop enforcement in CI
- Severity: Medium
- Description: `make lint` and `make lint.fix` exist but RuboCop checks are not enforced in CI. Add a workflow job to run RuboCop and optionally auto-fix with `rubocop -A` as a separate job.
- Suggested workflow snippet (add to `.github/workflows/ci.yml`):

```yaml
  rubocop:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
      - run: bundle install --jobs 4 --retry 3
      - run: bundle exec rubocop --format simple
```

### Documentation

1) README: add setup and developer onboarding
- Severity: Low
- Description: README is minimal. Add sections: prerequisites, local setup, running, database setup, common tasks, contributing.
- Suggested README snippet to add:

```
## Development

1. Install Ruby 3.3.1 and Node/npm
2. bundle install
3. bin/rails db:setup
4. bin/dev
```

### Containerization / Dev parity

1) Add docker-compose for local dev
- Severity: Low
- Description: Provide docker-compose to run app + Postgres + Redis for local development parity.
- Suggested `docker-compose.yml` snippet:

```yaml
version: '3.8'
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
    volumes:
      - db-data:/var/lib/postgresql/data
  web:
    build: .
    command: bin/dev
    volumes:
      - .:/app
    ports:
      - "3000:3000"
    depends_on:
      - db
volumes:
  db-data:
```

## Automated commands & patches
- `make lint`
- `make lint.fix`
- `make local.brakeman`
- `make security`
- `bundle audit check --update`

## What I changed
- Branch created: audit/second_breakfast-20251124
- Added: this REPORT.md
- Recommended next steps: open one issue per finding, labeled "🛡️ audit", including the above patches/commands.

## Blockers / Notes
- No tests to run; this is an implicit finding and will be recorded once when converting findings to issues.
