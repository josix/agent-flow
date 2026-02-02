# Project Detection

Comprehensive reference for project type detection and tooling configuration in the verification gate system.

---

## 1. Project Type Detection

The verification system automatically detects project type and configures appropriate checks. Detection is performed by analyzing project root files.

### Detection Priority

```
Project Type Detection Order:
1. package.json        -> Node.js
2. pyproject.toml      -> Python
3. setup.py            -> Python
4. Cargo.toml          -> Rust
5. go.mod              -> Go
6. pom.xml             -> Java (Maven)
7. build.gradle        -> Java (Gradle)
8. (none)              -> Unknown
```

### Detection Logic

```
function detectProjectType(rootDir):
    if exists(rootDir + "/package.json"):
        return "nodejs"
    elif exists(rootDir + "/pyproject.toml") or exists(rootDir + "/setup.py"):
        return "python"
    elif exists(rootDir + "/Cargo.toml"):
        return "rust"
    elif exists(rootDir + "/go.mod"):
        return "go"
    elif exists(rootDir + "/pom.xml"):
        return "java-maven"
    elif exists(rootDir + "/build.gradle"):
        return "java-gradle"
    else:
        return "unknown"
```

---

## 2. Test Framework Detection

### Node.js Test Frameworks

| Config Files Checked | Framework | Default Command |
|---------------------|-----------|-----------------|
| `jest.config.js`, `jest.config.ts`, `jest.config.mjs` | Jest | `npx jest` |
| `vitest.config.js`, `vitest.config.ts` | Vitest | `npx vitest run` |
| `.mocharc.json`, `.mocharc.js`, `mocha.opts` | Mocha | `npx mocha` |
| `karma.conf.js` | Karma | `npx karma start --single-run` |
| (default) | npm test | `npm test` |

**Detection Order**:
1. Check for Jest config
2. Check for Vitest config
3. Check for Mocha config
4. Check for Karma config
5. Fall back to `npm test`

### Python Test Frameworks

| Config Files Checked | Framework | Default Command |
|---------------------|-----------|-----------------|
| `pytest.ini`, `pyproject.toml[tool.pytest]` | pytest | `pytest` |
| `tox.ini` | tox | `tox` |
| (default) | unittest | `python -m unittest discover` |

**Detection Order**:
1. Check for pytest config
2. Check for tox config
3. Fall back to unittest

### Other Languages

| Language | Framework | Command |
|----------|-----------|---------|
| Rust | cargo test | `cargo test` |
| Go | go test | `go test ./...` |
| Java (Maven) | JUnit/Surefire | `mvn test` |
| Java (Gradle) | JUnit | `./gradlew test` |

---

## 3. Tooling Detection

### Node.js Tooling

| Tool | Detection Files | Environment Variable |
|------|-----------------|---------------------|
| TypeScript | `tsconfig.json` | `HAS_TYPESCRIPT=true` |
| ESLint | `.eslintrc.*`, `eslint.config.js`, `eslint.config.mjs` | `HAS_ESLINT=true` |
| Prettier | `.prettierrc`, `.prettierrc.*`, `prettier.config.js` | `HAS_PRETTIER=true` |
| Biome | `biome.json`, `biome.jsonc` | `HAS_BIOME=true` |

### Python Tooling

| Tool | Detection Files | Environment Variable |
|------|-----------------|---------------------|
| Ruff | `ruff.toml`, `pyproject.toml[tool.ruff]` | `HAS_RUFF=true` |
| Black | `pyproject.toml[tool.black]`, `.black` | `HAS_BLACK=true` |
| Mypy | `mypy.ini`, `pyproject.toml[tool.mypy]` | `HAS_MYPY=true` |
| Flake8 | `.flake8`, `setup.cfg[flake8]` | `HAS_FLAKE8=true` |
| isort | `pyproject.toml[tool.isort]`, `.isort.cfg` | `HAS_ISORT=true` |

### Go Tooling

| Tool | Detection | Environment Variable |
|------|-----------|---------------------|
| golangci-lint | `.golangci.yml`, `.golangci.yaml` | `HAS_GOLANGCI=true` |
| gofmt | (always available) | N/A |
| go vet | (always available) | N/A |

### Rust Tooling

| Tool | Detection | Environment Variable |
|------|-----------|---------------------|
| Clippy | (always with cargo) | N/A |
| rustfmt | (always with cargo) | N/A |
| cargo check | (always with cargo) | N/A |

---

## 4. Build System Detection

### Package Manager Detection

| Language | Detection | Package Manager |
|----------|-----------|-----------------|
| Node.js | `pnpm-lock.yaml` | pnpm |
| Node.js | `yarn.lock` | yarn |
| Node.js | `package-lock.json` | npm |
| Node.js | `bun.lockb` | bun |
| Python | `poetry.lock` | poetry |
| Python | `Pipfile.lock` | pipenv |
| Python | `requirements.txt` | pip |

### Build Command Detection

| Project Type | Config Check | Build Command |
|--------------|--------------|---------------|
| Node.js | `package.json["scripts"]["build"]` | `npm run build` |
| Python | `pyproject.toml[build-system]` | `python -m build` |
| Rust | (always) | `cargo build --release` |
| Go | (always) | `go build ./...` |
| Java Maven | `pom.xml` | `mvn package` |
| Java Gradle | `build.gradle` | `./gradlew build` |

---

## 5. Monorepo Detection

### Monorepo Tool Detection

| Tool | Detection Files | Behavior |
|------|-----------------|----------|
| Turborepo | `turbo.json` | Use `turbo run test` |
| Nx | `nx.json` | Use `nx run-many --target=test` |
| Lerna | `lerna.json` | Use `lerna run test` |
| pnpm workspaces | `pnpm-workspace.yaml` | Use `pnpm -r run test` |
| Yarn workspaces | `package.json["workspaces"]` | Use `yarn workspaces run test` |

### Monorepo Verification Strategy

For monorepo projects, verification adapts:

1. **Changed Package Detection**: Identify which packages have changes
2. **Targeted Testing**: Run tests only for affected packages
3. **Dependency Awareness**: Include tests for dependent packages
4. **Parallel Execution**: Run independent package tests in parallel

```
# Turborepo example
turbo run test --filter=./packages/changed/**

# Nx example
nx affected --target=test
```

---

## 6. CI/CD Environment Detection

### CI Environment Variables

| Environment | Detection Variable | Value |
|-------------|-------------------|-------|
| GitHub Actions | `GITHUB_ACTIONS` | `true` |
| GitLab CI | `GITLAB_CI` | `true` |
| CircleCI | `CIRCLECI` | `true` |
| Jenkins | `JENKINS_URL` | (set) |
| Travis CI | `TRAVIS` | `true` |
| Azure Pipelines | `TF_BUILD` | `True` |

### CI-Specific Adaptations

When running in CI:
- Disable interactive prompts
- Use machine-readable output formats
- Generate coverage reports
- Cache dependencies when possible
- Set appropriate timeouts

---

## 7. Configuration Examples

### Node.js Project Detection Output

```bash
# Example detection results
PROJECT_TYPE=nodejs
TEST_FRAMEWORK=jest
HAS_TYPESCRIPT=true
HAS_ESLINT=true
HAS_PRETTIER=true
PACKAGE_MANAGER=npm
BUILD_COMMAND="npm run build"
TEST_COMMAND="npm test"
LINT_COMMAND="npm run lint"
TYPE_CHECK_COMMAND="npx tsc --noEmit"
```

### Python Project Detection Output

```bash
# Example detection results
PROJECT_TYPE=python
TEST_FRAMEWORK=pytest
HAS_MYPY=true
HAS_RUFF=true
HAS_BLACK=true
PACKAGE_MANAGER=poetry
BUILD_COMMAND="python -m build"
TEST_COMMAND="pytest"
LINT_COMMAND="ruff check ."
TYPE_CHECK_COMMAND="mypy ."
```

---

## 8. Fallback Behavior

When detection fails or is ambiguous:

### No Project Type Detected

```
1. Check for common source directories (src/, lib/, app/)
2. Look for any test files (*test*, *spec*)
3. Attempt generic commands
4. Report manual configuration needed
```

### Multiple Project Types

```
1. Prioritize by root-level config presence
2. Allow explicit override via environment variable
3. Verify detection with user if ambiguous
```

### Missing Tools

When a detected tool is not installed:

```
1. Report missing tool
2. Suggest installation command
3. Skip that verification step (with warning)
4. Continue with available checks
```

---

## See Also

- [SKILL.md](../SKILL.md) - Main verification gates documentation
- [verification-commands.md](verification-commands.md) - Complete command reference
- [failure-handling.md](failure-handling.md) - Failure handling protocols
