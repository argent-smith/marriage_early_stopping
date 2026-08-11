.DEFAULT_GOAL := help

.PHONY: help setup setup-ocaml setup-python setup-ruby \
	demo demo-ocaml demo-python demo-ruby \
	test test-ocaml test-python test-ruby \
	lint fmt clean

help: ## Показать список целей
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: setup-ocaml setup-python setup-ruby ## Настроить все три песочницы (opam switch + uv venv + bundle)

setup-ocaml: ## Локальный opam switch в ocaml/ + все зависимости (включая alcotest)
	cd ocaml && ( test -d _opam || opam switch create . 5.3.0 --yes )
	cd ocaml && opam install . --deps-only --with-test --yes
	cd ocaml && opam install ocaml-lsp-server ocamlformat --yes

setup-python: ## Окружение python/.venv через uv (returns, pytest, ruff)
	cd python && uv sync

setup-ruby: ## Гемы в ruby/vendor/bundle через bundler (dry-monads, rspec, rubocop)
	cd ruby && bundle install

demo: demo-ocaml demo-python demo-ruby ## Прогнать все девять вариантов подряд

demo-ocaml: ## Три OCaml-варианта: функциональный, объектный, наивный
	@echo "--- ocaml: functional ---"
	cd ocaml && opam exec -- dune exec ./bin/marriage_early_stopping.exe
	@echo "--- ocaml: oop ---"
	cd ocaml && opam exec -- dune exec ./bin/marriage_early_stopping_oop.exe
	@echo "--- ocaml: naive ---"
	cd ocaml && opam exec -- dune exec ./bin/marriage_early_stopping_naive.exe

demo-python: ## Три Python-варианта: оригинал+обвязка, SOLID/Sandy Metz, FP/returns
	@echo "--- python: original + harness ---"
	cd python && uv run python marriage_early_stopping.py
	@echo "--- python: oop (SOLID + Sandy Metz) ---"
	cd python && uv run python marriage_early_stopping_oop.py
	@echo "--- python: fp (returns) ---"
	cd python && uv run python marriage_early_stopping_fp.py

demo-ruby: ## Три Ruby-варианта: наивный, SOLID/Sandy Metz, FP/dry-monads
	@echo "--- ruby: naive ---"
	cd ruby && bundle exec ruby marriage_early_stopping_naive.rb
	@echo "--- ruby: oop (SOLID + Sandy Metz) ---"
	cd ruby && bundle exec ruby marriage_early_stopping_oop.rb
	@echo "--- ruby: fp (dry-monads) ---"
	cd ruby && bundle exec ruby marriage_early_stopping_fp.rb

test: test-ocaml test-python test-ruby ## Прогнать тесты всех трёх субпроектов

test-ocaml: ## Alcotest-юнит-тесты (ocaml/test)
	cd ocaml && opam exec -- dune test

test-python: ## pytest (python/tests)
	cd python && uv run pytest

test-ruby: ## RSpec (ruby/spec)
	cd ruby && bundle exec rspec

lint: ## ruff (python/) + rubocop (ruby/), без изменений файлов
	cd python && uv run ruff check .
	cd python && uv run ruff format --check .
	cd ruby && bundle exec rubocop

fmt: ## ruff format (python/) + rubocop -a (ruby/); marriage_early_stopping.py не трогается — транскрипция 1:1
	cd python && uv run ruff format .
	cd ruby && bundle exec rubocop -a

clean: ## Убрать сборочные артефакты (песочницы не трогает)
	rm -rf ocaml/_build
	rm -rf python/__pycache__ python/tests/__pycache__ python/.pytest_cache python/.ruff_cache
	rm -f ruby/.rspec_status
