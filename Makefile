.PHONY: help deps compile test test-property cover cover-html format check clean docs checksum publish-dry publish

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

deps: ## Install dependencies
	mix deps.get

compile: ## Compile the project
	mix compile

test: ## Run all tests (unit + property)
	mix test

test-property: ## Run property-based tests only
	mix test test/ex_tholos_pq_property_test.exs

cover: ## Run tests with coverage report
	mix coveralls

cover-html: ## Run tests and open HTML coverage report
	mix coveralls.html
	open cover/excoveralls.html

format: ## Format Elixir and Rust code
	mix format
	cargo fmt --manifest-path native/ex_tholos_pq_nif/Cargo.toml

check: ## Run all checks (format, compile, test, property tests)
	mix format --check-formatted
	cargo fmt --manifest-path native/ex_tholos_pq_nif/Cargo.toml -- --check
	cargo clippy --manifest-path native/ex_tholos_pq_nif/Cargo.toml -- -D warnings
	mix compile --warnings-as-errors
	mix coveralls

clean: ## Clean build artifacts
	mix clean
	cargo clean --manifest-path native/ex_tholos_pq_nif/Cargo.toml
	rm -rf _build deps priv

docs: ## Generate documentation
	mix docs

docs-open: docs ## Generate and open documentation in browser
	open doc/index.html

checksum: ## Download precompiled NIFs and generate checksum file (after tag release)
	mix rustler_precompiled.download ExTholosPq --all --print

publish-dry: ## Dry run of hex publish
	mix hex.build
	@echo "Package built successfully. Review the tarball before publishing."

publish: ## Publish to hex.pm
	@echo "Publishing to hex.pm..."
	mix hex.publish

.DEFAULT_GOAL := help

