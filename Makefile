APP_NAME=second_breakfast
RAILS_ENV ?= development
SHELL := /bin/bash

GREEN := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
RESET := $(shell tput -Txterm sgr0)

# RVM setup - ensure we're using the right Ruby version
RVM_USE := source ~/.rvm/scripts/rvm && rvm use

.DEFAULT_GOAL := help

# -----------------------------
# 🥞 Local Development
# -----------------------------

local.run: ## Run the Rails app (with bin/dev)
	@echo "$(GREEN)==> Running $(APP_NAME) in $(RAILS_ENV)...$(RESET)"
	$(RVM_USE) && bin/dev

local.setup: ## Full setup - install gems, setup db, tailwind, seed
	@echo "$(GREEN)==> Setting up $(APP_NAME)...$(RESET)"
	$(RVM_USE) && bundle install
	$(RVM_USE) && bin/rails db:create
	$(RVM_USE) && bin/rails db:migrate
	$(RVM_USE) && bin/rails db:seed
	@echo "$(GREEN)==> Setup complete! Run 'make local.run' to start the app$(RESET)"

local.install: ## Install Ruby dependencies
	@echo "$(GREEN)==> Installing dependencies...$(RESET)"
	$(RVM_USE) && bundle install

local.update: ## Update all gems
	@echo "$(GREEN)==> Updating gems...$(RESET)"
	$(RVM_USE) && bundle update

# -----------------------------
# 🗄️  Database Management
# -----------------------------

local.db.create: ## Create the database
	@echo "$(GREEN)==> Creating database...$(RESET)"
	$(RVM_USE) && bin/rails db:create

local.db.drop: ## Drop the database
	@echo "$(YELLOW)==> Dropping database...$(RESET)"
	$(RVM_USE) && bin/rails db:drop

local.db.migrate: ## Run database migrations
	@echo "$(GREEN)==> Running migrations...$(RESET)"
	$(RVM_USE) && bin/rails db:migrate

local.db.rollback: ## Rollback last migration
	@echo "$(YELLOW)==> Rolling back last migration...$(RESET)"
	$(RVM_USE) && bin/rails db:rollback

local.db.seed: ## Seed the database
	@echo "$(GREEN)==> Seeding database...$(RESET)"
	$(RVM_USE) && bin/rails db:seed

local.db.reset: ## Reset the database (drop, create, migrate, seed)
	@echo "$(YELLOW)==> Resetting database...$(RESET)"
	$(RVM_USE) && bin/rails db:reset

local.db.status: ## Show migration status
	@echo "$(GREEN)==> Database migration status:$(RESET)"
	$(RVM_USE) && bin/rails db:migrate:status

# -----------------------------
# 🔧 Rails Commands
# -----------------------------

console: ## Start Rails console
	@echo "$(GREEN)==> Starting Rails console...$(RESET)"
	$(RVM_USE) && bin/rails console

routes: ## Show all routes
	@echo "$(GREEN)==> Application routes:$(RESET)"
	$(RVM_USE) && bin/rails routes

server: ## Start Rails server (without assets)
	@echo "$(GREEN)==> Starting Rails server...$(RESET)"
	$(RVM_USE) && bin/rails server

# -----------------------------
# 🎨 Assets & Frontend
# -----------------------------

assets.precompile: ## Precompile assets
	@echo "$(GREEN)==> Precompiling assets...$(RESET)"
	$(RVM_USE) && bin/rails assets:precompile

assets.clean: ## Clean compiled assets
	@echo "$(GREEN)==> Cleaning assets...$(RESET)"
	$(RVM_USE) && bin/rails assets:clean

tailwind.build: ## Build Tailwind CSS
	@echo "$(GREEN)==> Building Tailwind CSS...$(RESET)"
	$(RVM_USE) && bin/rails tailwindcss:build

tailwind.watch: ## Watch and rebuild Tailwind CSS
	@echo "$(GREEN)==> Watching Tailwind CSS...$(RESET)"
	$(RVM_USE) && bin/rails tailwindcss:watch

# -----------------------------
# 🧪 Testing & Quality
# -----------------------------

local.test: ## Run all tests
	@echo "$(GREEN)==> Running tests...$(RESET)"
	$(RVM_USE) && bin/rails test

local.test.system: ## Run system tests
	@echo "$(GREEN)==> Running system tests...$(RESET)"
	$(RVM_USE) && bin/rails test:system

lint: ## Run RuboCop linting
	@echo "$(GREEN)==> Running RuboCop...$(RESET)"
	$(RVM_USE) && bundle exec rubocop

lint.fix: ## Auto-fix RuboCop issues
	@echo "$(GREEN)==> Auto-fixing RuboCop issues...$(RESET)"
	$(RVM_USE) && bundle exec rubocop -A

local.brakeman: ## Run Brakeman static security analysis
	@echo "$(GREEN)==> Running Brakeman security scan...$(RESET)"
	$(RVM_USE) && bin/brakeman --exit-on-warn --no-pager

security: local.brakeman ## Run security checks

# -----------------------------
# 🧹 Maintenance
# -----------------------------

clean: ## Clean tmp, log, and cached files
	@echo "$(GREEN)==> Cleaning temporary files...$(RESET)"
	$(RVM_USE) && bin/rails tmp:clear
	$(RVM_USE) && bin/rails log:clear
	rm -rf tmp/cache/*

clean.all: clean ## Deep clean (includes node_modules)
	@echo "$(YELLOW)==> Deep cleaning...$(RESET)"
	rm -rf node_modules
	rm -rf public/assets
	rm -rf tmp/*

restart: ## Restart the Rails server
	@echo "$(GREEN)==> Restarting server...$(RESET)"
	$(RVM_USE) && bin/rails restart

# -----------------------------
# 📦 Deployment
# -----------------------------

deploy.check: ## Check deployment configuration
	@echo "$(GREEN)==> Checking deployment configuration...$(RESET)"
	$(RVM_USE) && bin/kamal config

deploy.setup: ## Setup deployment infrastructure
	@echo "$(GREEN)==> Setting up deployment infrastructure...$(RESET)"
	$(RVM_USE) && bin/kamal setup

deploy: ## Deploy to production
	@echo "$(GREEN)==> Deploying to production...$(RESET)"
	$(RVM_USE) && bin/kamal deploy

# -----------------------------
# 🔍 Information
# -----------------------------

version: ## Show Rails and Ruby versions
	@echo "$(GREEN)Ruby version:$(RESET)"
	@$(RVM_USE) && ruby --version
	@echo "$(GREEN)Rails version:$(RESET)"
	@$(RVM_USE) && bin/rails --version
	@echo "$(GREEN)Bundler version:$(RESET)"
	@$(RVM_USE) && bundle --version

info: version ## Show application information
	@echo "$(GREEN)Application:$(RESET) $(APP_NAME)"
	@echo "$(GREEN)Environment:$(RESET) $(RAILS_ENV)"

# -----------------------------
# 📚 Help
# -----------------------------

help: ## Show all available make targets
	@echo "$(GREEN)Available targets for $(APP_NAME):$(RESET)"
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-25s$(RESET) %s\n", $$1, $$2}'

.PHONY: help local.run local.setup local.install local.update \
	local.db.create local.db.drop local.db.migrate local.db.rollback \
	local.db.seed local.db.reset local.db.status \
	console routes server \
	assets.precompile assets.clean tailwind.build tailwind.watch \
	local.test local.test.system lint lint.fix local.brakeman security \
	clean clean.all restart \
	deploy.check deploy.setup deploy \
	version info
