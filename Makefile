.PHONY: run lint test fmt migrate hooks

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
