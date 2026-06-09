.PHONY: run lint test fmt migrate hooks dev dev-down dev-logs \
        macos ios open-macos open-ios

MACOS_PROJECT  := clients/macos/moringa/moringa.xcodeproj
MACOS_SCHEME   := moringa
MACOS_BUILD    := $(HOME)/Library/Developer/Xcode/DerivedData/moringa-macos

IOS_PROJECT    := clients/ios/moringa/moringa.xcodeproj
IOS_SCHEME     := moringa
IOS_SIM_ID     := F49C1106-5301-4696-BD5F-D2AFDC2D8DA8
IOS_BUILD      := $(HOME)/Library/Developer/Xcode/DerivedData/moringa-ios

run:
	cd server && go run ./cmd/moringa

lint:
	cd server && golangci-lint run ./...

test:
	cd server && go test ./...

fmt:
	cd server && gofmt -w ./..

migrate:
	psql "$$DATABASE_URL" -f server/migrations/001_init.sql
	psql "$$DATABASE_URL" -f server/migrations/002_add_format.sql

hooks:
	./scripts/install-hooks.sh

dev:
	docker compose -f docker-compose.dev.yml up --build

dev-down:
	docker compose -f docker-compose.dev.yml down

dev-logs:
	docker compose -f docker-compose.dev.yml logs -f server

# ── macOS app ──────────────────────────────────────────────────────────────────
macos:
	xcodebuild \
		-project $(MACOS_PROJECT) \
		-scheme  $(MACOS_SCHEME) \
		-configuration Debug \
		-derivedDataPath $(MACOS_BUILD) \
		build -quiet
	@echo "Build complete — launching macOS app…"
	@APP=$$(find $(MACOS_BUILD) -name "moringa.app" -maxdepth 6 | head -1); \
	 if [ -n "$$APP" ]; then open "$$APP"; else echo "ERROR: moringa.app not found in $(MACOS_BUILD)"; exit 1; fi

open-macos:
	@APP=$$(find $(MACOS_BUILD) -name "moringa.app" -maxdepth 6 | head -1); \
	 if [ -n "$$APP" ]; then open "$$APP"; else echo "Run 'make macos' first"; exit 1; fi

# ── iOS app ────────────────────────────────────────────────────────────────────
ios:
	@echo "Booting simulator $(IOS_SIM_ID)…"
	xcrun simctl boot $(IOS_SIM_ID) 2>/dev/null || true
	open -a Simulator
	xcodebuild \
		-project $(IOS_PROJECT) \
		-scheme  $(IOS_SCHEME) \
		-configuration Debug \
		-derivedDataPath $(IOS_BUILD) \
		-destination "id=$(IOS_SIM_ID)" \
		build -quiet
	@echo "Installing and launching on simulator…"
	@APP=$$(find $(IOS_BUILD) -name "moringa.app" -maxdepth 8 | head -1); \
	 if [ -z "$$APP" ]; then echo "ERROR: moringa.app not found in $(IOS_BUILD)"; exit 1; fi; \
	 xcrun simctl install $(IOS_SIM_ID) "$$APP"; \
	 BUNDLE=$$(xcrun simctl listapps $(IOS_SIM_ID) 2>/dev/null | grep -A1 '"moringa"' | grep CFBundleIdentifier | sed 's/.*=> //;s/;//;s/"//g' | head -1); \
	 if [ -z "$$BUNDLE" ]; then BUNDLE=$$(defaults read "$$APP/Info" CFBundleIdentifier 2>/dev/null); fi; \
	 echo "Launching $$BUNDLE…"; \
	 xcrun simctl launch $(IOS_SIM_ID) "$$BUNDLE"

open-ios:
	open -a Simulator
	@APP=$$(find $(IOS_BUILD) -name "moringa.app" -maxdepth 8 | head -1); \
	 if [ -z "$$APP" ]; then echo "Run 'make ios' first"; exit 1; fi; \
	 BUNDLE=$$(defaults read "$$APP/Info" CFBundleIdentifier 2>/dev/null); \
	 xcrun simctl launch $(IOS_SIM_ID) "$$BUNDLE"
