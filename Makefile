.PHONY: lint test smoke compat build clean ci

lint:
	shellcheck unleash lib/*.sh examples/*.sh tests/smoke.sh
	bash -n unleash lib/*.sh examples/*.sh tests/smoke.sh

test:
	bats tests/*.bats

# End-to-end checks that need neither bats nor macOS: command dispatch, the
# standalone artifact, captured-value hygiene, dry run, JSON output.
smoke:
	bash tests/smoke.sh

# Portability rules for a minimal Recovery environment: bash 3.2 only, and no
# reliance on dirname/basename/readlink/realpath.
compat:
	@! grep -vE '^[[:space:]]*#' unleash lib/*.sh examples/*.sh | \
	  grep -E '(^|[^[:alnum:]_])(dirname|basename|readlink|realpath)([^[:alnum:]_]|$)' || \
	  { echo "dirname/basename/readlink/realpath found — not available in Recovery"; exit 1; }
	@echo "compat: OK"

build:
	./examples/build-standalone.sh
	bash -n unleash-standalone.sh

clean:
	rm -f unleash-standalone.sh

ci: lint build smoke
	@echo "=== All checks done ==="
