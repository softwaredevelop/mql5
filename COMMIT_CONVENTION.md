# Commit Convention Guide

This project follows the **Conventional Commits** specification to maintain a clean, readable, and automated commit history.

## 1. Commit Message Format

Each commit message consists of a **header**, a **body** (optional), and a **footer** (optional).

```text
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Example

`feat(vwap): implement state snapshot logic for incremental calculation`

---

## 2. Types

Must be one of the following:

| Type | Description | Example |
| :--- | :--- | :--- |
| **`feat`** | A new feature (e.g., new indicator, new parameter). | `feat(bb): add Bollinger Band Width indicator` |
| **`fix`** | A bug fix. | `fix(session): resolve object deletion issue on timeframe change` |
| **`refactor`** | A code change that neither fixes a bug nor adds a feature. | `refactor(core): extract MovingAverage_Engine class` |
| **`docs`** | Documentation only changes. | `docs(readme): update installation instructions` |
| **`style`** | Changes that do not affect the meaning of the code (white-space, formatting). | `style(all): fix indentation in header files` |
| **`perf`** | A code change that improves performance. | `perf(ha): optimize Heikin Ashi calculation loop` |
| **`chore`** | Changes to the build process, auxiliary tools, or config files. | `chore(presets): add default set files` |

---

## 3. Scopes

The scope provides context to the commit. Use the following standard scopes for this project:

### Core Engines

* **`core`**: General shared libraries (`MovingAverage_Engine`, etc.).
* **`ha`**: Heikin Ashi tools (`HeikinAshi_Tools`).

### Indicators (Modules)

* **`bb`**: Bollinger Bands family.
* **`stoch`**: Stochastic family (Slow, RSI, etc.).
* **`ma`**: Moving Average Pro & HMA.
* **`vwap`**: VWAP Pro.
* **`adx`**: ADX Pro.
* **`smi`**: SMI Pro.
* **`linreg`**: Linear Regression suite.
* **`session`**: Session Analysis Pro.
* **`laguerre`**: Laguerre family (Filter, RSI).
* **`ehlers`**: Other Ehlers indicators (Smoother, BandPass).

### Resources

* **`presets`**: `.set` files.
* **`templates`**: `.tpl` files.
* **`scripts`**: Utility scripts (`Workspace_Loader`, etc.).

---

## 4. Subject Rules

1. Use the imperative, present tense: "change" not "changed" nor "changes".
2. Don't capitalize the first letter.
3. No dot (.) at the end.

## 5. Examples

* `feat(session): add single market edition for MQL4`
* `fix(vwap): prevent real volume error on unsupported brokers`
* `refactor(stoch): switch to composite design using MA engine`
* `docs(bb): add mathematical formulas to documentation`
* `chore(templates): update dark theme template`
