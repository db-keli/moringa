.PHONY: run lint test fmt migrate hooks dev dev-down dev-logs

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

hooks:
	./scripts/install-hooks.sh

dev:
	docker compose -f docker-compose.dev.yml up --build

dev-down:
	docker compose -f docker-compose.dev.yml down

dev-logs:
	docker compose -f docker-compose.dev.yml logs -f server
