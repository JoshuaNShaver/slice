# The local stack, run like the deploy workflow (002-deploy-code) but on
# this Mac: Supabase settings, then migrations, then the release, then a
# check that it answers. `make web-local` does it all; rerun it after any
# change.

# Settings from .env, passed to everything this runs (e.g. the
# SUPABASE_AUTH_EXTERNAL_GOOGLE_* pair that `supabase start` needs for
# Google login). `make VAR=value` overrides anything here.
-include .env
export

# Supabase calls docker.
PATH := $(HOME)/.docker/bin:$(PATH)

# The local stack uses local Supabase; `make web-local SAVES=local` skips it
# (JSON saves, guest logins). Not read from .env.
SAVES := supabase
GODOT ?= /Applications/Godot.app/Contents/MacOS/Godot
PORT ?= 24680
WEB_PORT ?= 8000
# Where the browser reaches the page and server. With Supabase, 127.0.0.1:
# Google login comes back through Supabase on 127.0.0.1, so it only works on
# this Mac. Without it, this Mac's LAN IP, so a phone can play too.
# `make HOST=...` overrides it.
LAN_IP := $(shell ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)
ifeq ($(SAVES),supabase)
HOST := 127.0.0.1
else
HOST := $(LAN_IP)
endif
# Server the web build joins.
WEB_SERVER = ws://$(HOST):$(PORT)

# What local Supabase was started with. It reads config.toml and .env only
# when it starts, so when this changes it restarts (the local `config push`).
SUPABASE_STAMP := build/.supabase-config
SUPABASE_CONFIG = $$( { cat supabase/config.toml; echo "$$SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID $$SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET"; } | shasum | cut -c1-40 )

# Shell snippet: point the server at local Supabase, keys from `supabase status`.
SUPABASE_ENV = if [ "$(SAVES)" = supabase ]; then \
	eval "$$(supabase status -o env 2>/dev/null)"; \
	export SUPABASE_URL="$$API_URL" SUPABASE_SECRET_KEY="$$SECRET_KEY" SUPABASE_PUBLISHABLE_KEY="$$PUBLISHABLE_KEY"; \
	fi

.PHONY: web-local web server stop supabase migrate supabase-stop supabase-reset check

## Everything: stop old copies, Supabase settings, migrations, export, then
## run the server and page and check they answer. Ctrl-C stops server and
## page (Supabase keeps running).
web-local: stop supabase migrate web
	@trap 'kill $$server $$web 2>/dev/null' EXIT INT TERM; \
	$(SUPABASE_ENV); \
	"$(GODOT)" --headless --path . -- --server --port=$(PORT) & server=$$!; \
	python3 -m http.server $(WEB_PORT) --directory build/web >/dev/null 2>&1 & web=$$!; \
	ok=; for i in $$(seq 30); do \
		curl -fs -o /dev/null http://127.0.0.1:$(WEB_PORT)/index.html \
			&& nc -z 127.0.0.1 $(PORT) 2>/dev/null && { ok=1; break; }; sleep 1; done; \
	if [ -z "$$ok" ]; then printf '\033[1;31mServer or page did not answer. See the output above.\033[0m\n'; exit 1; fi; \
	bar="=========================================="; \
	printf '\n\033[1;32m%s\n  PLAY:     http://%s:%s\n' "$$bar" "$(HOST)" "$(WEB_PORT)"; \
	if [ "$(HOST)" = "$(LAN_IP)" ]; then printf '  LAN:      http://%s:%s   (phones on this Wi-Fi)\n' "$(LAN_IP)" "$(WEB_PORT)"; \
	else printf '  LAN:      %s   (phones: make web-local SAVES=local)\n' "$(LAN_IP)"; fi; \
	printf '  server:   %s   saves: %s\n' "$(WEB_SERVER)" "$(SAVES)"; \
	if [ "$(SAVES)" = supabase ]; then printf '  Supabase: %s\n  Studio:   %s\n' "$$API_URL" "$$STUDIO_URL"; fi; \
	printf '  Ctrl-C stops server + page\n%s\033[0m\n\n' "$$bar"; \
	wait

## Export the web build pointed at WEB_SERVER (log 0135).
web:
	SLICE_SERVER=$(WEB_SERVER) "$(GODOT)" --headless --path . --export-release "Web" build/web/index.html

## Just the dedicated server.
server: stop supabase migrate
	@$(SUPABASE_ENV); "$(GODOT)" --headless --path . -- --server --port=$(PORT)

## Kill whatever is listening on the server and web ports.
stop:
	@for p in $(PORT) $(WEB_PORT); do \
		pids=$$(lsof -ti tcp:$$p -sTCP:LISTEN); \
		if [ -n "$$pids" ]; then echo "Stopping port $$p ($$pids)"; kill $$pids; fi; \
	done; true

## Supabase settings: start Docker Desktop and local Supabase if needed, and
## restart Supabase when config.toml or .env's Google settings changed.
supabase:
	@if [ "$(SAVES)" != supabase ]; then exit 0; fi; \
	if ! docker info >/dev/null 2>&1; then \
		echo "Starting Docker Desktop..."; open -a Docker; \
		for i in $$(seq 60); do docker info >/dev/null 2>&1 && break; sleep 2; done; \
		docker info >/dev/null 2>&1 || { echo "Docker didn't start."; exit 1; }; \
	fi; \
	want=$(SUPABASE_CONFIG); \
	if supabase status >/dev/null 2>&1; then \
		if [ "$$(cat $(SUPABASE_STAMP) 2>/dev/null)" != "$$want" ]; then \
			echo "Supabase settings changed (config.toml or .env): restarting it."; supabase stop; \
		else echo "Supabase running, settings unchanged."; fi; \
	fi; \
	if ! supabase status >/dev/null 2>&1; then \
		if [ -z "$$SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID" ]; then \
			printf '\033[1;33mSUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID/_SECRET not in .env: Google login won'\''t work.\033[0m\n'; fi; \
		supabase start || exit 1; \
	fi; \
	mkdir -p build; echo "$$want" > $(SUPABASE_STAMP)

## Migrations: list what's pending, then apply supabase/migrations/ to the
## local database (the local `db push`).
migrate: supabase
	@if [ "$(SAVES)" != supabase ]; then exit 0; fi; \
	supabase migration list --local 2>/dev/null; \
	supabase migration up --local

## Stop local Supabase (keeps its data).
supabase-stop:
	supabase stop

## Wipe the local database and reapply every migration.
supabase-reset: supabase
	supabase db reset --local

## Check scripts for errors.
check:
	"$(GODOT)" --headless --path . --quit-after 60
