# Verification Commands Reference

Complete command reference for all verification gates across supported languages and environments.

---

## Node.js / TypeScript

### Standard Commands

| Gate | Command | Flags | Description |
|------|---------|-------|-------------|
| Tests | `npm test` | `-- --coverage` | Run test suite with optional coverage |
| Tests (Jest) | `npx jest` | `--verbose --runInBand` | Verbose output, sequential execution |
| Tests (Vitest) | `npx vitest run` | `--reporter=verbose` | Single run with detailed output |
| Type Check | `npx tsc --noEmit` | `--pretty --incremental` | Type-only check, no output files |
| Lint | `npm run lint` | `-- --fix` | Run ESLint with auto-fix option |
| Lint (direct) | `npx eslint .` | `--max-warnings=0` | Treat warnings as errors |
| Format | `npx prettier --check .` | `--write` | Check or auto-format files |
| Build | `npm run build` | | Production build |

### Debug/Verbose Options

```bash
# Verbose test output with stack traces
npm test -- --verbose --detectOpenHandles

# TypeScript with detailed error output
npx tsc --noEmit --extendedDiagnostics

# ESLint with debug info
DEBUG=eslint:* npm run lint

# Jest specific file
npx jest path/to/file.test.ts --verbose
```

---

## Python

### Standard Commands

| Gate | Command | Flags | Description |
|------|---------|-------|-------------|
| Tests | `pytest` | `-v --tb=short` | Verbose with short tracebacks |
| Tests | `python -m pytest` | `--cov=src` | With coverage reporting |
| Type Check | `mypy .` | `--strict` | Strict type checking mode |
| Type Check | `pyright` | | Alternative type checker |
| Lint | `ruff check .` | `--fix` | Fast linter with auto-fix |
| Lint | `flake8` | `--max-line-length=100` | Classic linter |
| Format | `black --check .` | `--diff` | Check formatting, show diff |
| Build | `python -m build` | `--wheel` | Build distribution packages |

### Debug/Verbose Options

```bash
# Pytest with full output and no capture
pytest -v -s --tb=long

# Mypy with detailed error codes
mypy . --show-error-codes --show-column-numbers

# Ruff with explanation of rules
ruff check . --show-fixes --output-format=full
```

---

## Go

### Standard Commands

| Gate | Command | Flags | Description |
|------|---------|-------|-------------|
| Tests | `go test ./...` | `-v -race` | Verbose with race detection |
| Tests | `go test ./...` | `-cover -coverprofile=coverage.out` | With coverage |
| Type Check | `go build ./...` | `-v` | Compile check (no binary output) |
| Lint | `golangci-lint run` | `--fix` | Comprehensive linter with fix |
| Vet | `go vet ./...` | | Built-in static analysis |
| Format | `gofmt -l .` | `-d` | List unformatted, show diff |
| Build | `go build -o bin/app` | `-ldflags="-s -w"` | Release build, stripped |

### Debug/Verbose Options

```bash
# Verbose test with all package output
go test ./... -v -count=1

# golangci-lint with specific linters
golangci-lint run --enable-all --disable=gochecknoglobals

# Build with all warnings
go build -v -gcflags="-m" ./...
```

---

## Rust

### Standard Commands

| Gate | Command | Flags | Description |
|------|---------|-------|-------------|
| Tests | `cargo test` | `-- --nocapture` | Tests with stdout visible |
| Tests | `cargo test` | `--all-features` | Test all feature combinations |
| Type Check | `cargo check` | `--all-targets` | Fast type checking |
| Lint | `cargo clippy` | `-- -D warnings` | Warnings as errors |
| Format | `cargo fmt --check` | `--all` | Check all workspace crates |
| Build | `cargo build --release` | | Optimized release build |
| Doc | `cargo doc` | `--no-deps` | Build documentation |

### Debug/Verbose Options

```bash
# Verbose test output
cargo test -- --nocapture --test-threads=1

# Clippy with all lints
cargo clippy --all-targets --all-features -- -W clippy::all

# Build with timing info
cargo build --release --timings
```

---

## Java

### Maven Commands

| Gate | Command | Flags | Description |
|------|---------|-------|-------------|
| Tests | `mvn test` | `-Dtest=ClassName` | Run specific test class |
| Type Check | `mvn compile` | `-X` | Compile with debug output |
| Lint | `mvn checkstyle:check` | | Checkstyle validation |
| Build | `mvn package` | `-DskipTests` | Package without tests |
| Verify | `mvn verify` | | Full verification lifecycle |

### Gradle Commands

| Gate | Command | Flags | Description |
|------|---------|-------|-------------|
| Tests | `./gradlew test` | `--info` | Run tests with info logging |
| Type Check | `./gradlew compileJava` | | Compile main sources |
| Lint | `./gradlew checkstyleMain` | | Checkstyle on main sources |
| Build | `./gradlew build` | `-x test` | Build without tests |
| Verify | `./gradlew check` | | All verification tasks |

### Debug/Verbose Options

```bash
# Maven verbose test output
mvn test -Dsurefire.useFile=false -DtrimStackTrace=false

# Gradle with stacktrace
./gradlew test --stacktrace --info
```

---

## CI/CD Pipeline Integration

### GitHub Actions

```yaml
# Standard verification job
verify:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Install dependencies
      run: npm ci
    - name: Type check
      run: npx tsc --noEmit
    - name: Lint
      run: npm run lint
    - name: Test
      run: npm test -- --coverage
    - name: Build
      run: npm run build
```

### GitLab CI

```yaml
verify:
  stage: test
  script:
    - npm ci
    - npx tsc --noEmit
    - npm run lint
    - npm test
    - npm run build
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

echo "Running pre-commit checks..."
npm run lint -- --max-warnings=0
npx tsc --noEmit
npm test -- --bail --findRelatedTests $(git diff --cached --name-only)
```

---

## Environment-Specific Variations

### Monorepo (Turborepo/Nx)

```bash
# Turborepo
turbo run test --filter=./packages/changed/**
turbo run lint build --parallel

# Nx
nx affected --target=test
nx run-many --target=lint --all
```

### Docker-based Testing

```bash
# Run tests in container
docker compose run --rm app npm test

# Build verification
docker build --target=test .
```

### Watch Mode (Development Only)

```bash
# Node.js
npm test -- --watch
npx tsc --watch --noEmit

# Python
pytest-watch

# Rust
cargo watch -x test
```

---

## Exit Code Reference

| Exit Code | Meaning | Action Required |
|-----------|---------|-----------------|
| 0 | Success | Gate passed |
| 1 | Failure | Fix issues, re-run |
| 2 | Command error | Check command syntax |
| 124 | Timeout | Increase timeout or optimize |
| 130 | Interrupted (Ctrl+C) | Re-run check |

---

## See Also

- [SKILL.md](../SKILL.md) - Main verification gates documentation
- [verification-scenarios.md](../examples/verification-scenarios.md) - Worked examples
