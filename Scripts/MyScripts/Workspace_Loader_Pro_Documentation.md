# Automated Workspace & Template Bulk Loader Pro (v3.21)

Quantitative Operational Workflow & Multi-Chart Template Deployment Suite

---

## 1. Summary (Introduction)

**Workspace Loader Pro** is an institutional operational script designed to automate the rapid deployment, configuration, and organization of multi-symbol, multi-timeframe chart layouts in MetaTrader 5.

Manually opening 15–20 currency pairs across multiple timeframes and applying custom strategy templates requires over a hundred repetitive clicks and is prone to operational errors. **Workspace Loader Pro reduces this entire workspace initialization process into a single, deterministic execution**:

* **Multi-Symbol Sourcing:** Instantly processes custom comma-separated symbol lists or bulk-loads all active instruments directly from the **Market Watch window**.
* **Up to 8 Configurable Chart Slots per Asset:** Automatically provisions multi-timeframe analysis grids (e.g., M5 Scalping + M15 Tactical Flow + H1 Strategic Bias + H4 Trend).
* **Smart Template Path Resolution:** Automatically resolves subfolder structures within `MQL5\Profiles\Templates\`, eliminating the need to repeatedly type full directory paths for each slot.
* **Duplicate Chart Prevention:** Traverses existing open charts to prevent accidental clutter and memory bloat upon repeated script execution.
* **Asynchronous Safety Delay:** Introduces a non-blocking micro-delay (`InpDelayMs = 50 ms`) to allow MetaTrader 5's internal chart manager to register handles cleanly before applying templates, preventing UI thread freezing and template application race conditions.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   WORKSPACE LOADER AUTOMATION ENGINE                   │
├────────────────────────────────────────────────────────────────────────┤
│  Symbol Source  ───►  Market Watch (All Active) OR Custom Symbol List  │
│  Slot Configs   ───►  Up to 8 Independent [Timeframe + Template] Slots │
│  Smart Resolver ───►  Auto-Resolves Path: BaseDir + TemplateName + .tpl│
│  Duplicate Guard───►  Checks Open Charts ──► Skips Redundant Tabs      │
│  Async Deploy   ───►  ChartOpen() ──► Sleep(50ms) ──► ChartApplyTemplate│
└────────────────────────────────────────────────────────────────────────┘

```

---

## 2. Workspace Architecture & Smart Path Resolution

```text

                  TERMINAL TEMPLATE DIRECTORY ROOT:
                 MQL5\Profiles\Templates\ (Default Root)
                                    │
       ┌────────────────────────────┴────────────────────────────┐
       ▼                                                         ▼
  default.tpl                                              MyTemplates\
  (Root Template)                                                │
                                               ┌─────────────────┴─────────────────┐
                                               ▼                                   ▼
                                          Scalping\                           Strategies\
                                               │                                   │
                                          m1_scalp.tpl             trend.std.tsi_vbands.tpl

```

### 2.1. Template Path Resolution Algorithm (`FormatTemplatePath`)

The MetaTrader 5 native API function `ChartApplyTemplate(chart_id, filename)` strictly searches within `<terminal_data_directory>\MQL5\Profiles\Templates\`.

`Workspace Loader Pro` provides a **Smart Base Directory (`InpTemplateBaseDir`)** engine that automatically formats and resolves template paths:

1. **Automatic Slash Normalization:** Converts forward slashes (`/`) to Windows-compliant backslashes (`\`).
2. **Automatic Extension Handshake:** Verifies and appends the `.tpl` file extension if omitted by the user.
3. **Subfolder Concatenation:** If `InpTemplateBaseDir` is configured (e.g., `"MyTemplates\Strategies"`), the script automatically prepends the directory path to short template names:
   $$\text{Slot Input: } \text{"trend.std.tsi\_vbands"} \implies \text{Resolved: } \text{"MyTemplates\textbackslash Strategies\textbackslash trend.std.tsi\_vbands.tpl"}$$
4. **Root Exception Handling:** If a template explicitly targets the root directory (e.g., `"default"` or `"default.tpl"`), the base directory prefix is automatically bypassed.
5. **Sanitization:** Removes duplicate consecutive slashes (`\\`) and trailing spaces.

---

## 3. Execution Safety Standards & Engineering

1. **Race-Condition & UI Freeze Prevention:**
   Opening dozens of charts synchronously can overwhelm the terminal's user interface queue. By enforcing a micro-delay (`InpDelayMs = 50 ms`), each chart handle is properly instantiated and registered by the operating system before `ChartApplyTemplate` is executed.
2. **Duplicate Chart Prevention (`IsChartAlreadyOpen`):**
   Traverses all open charts in memory using `ChartFirst()` and `ChartNext()`. If a chart with the identical `Symbol` and `ENUM_TIMEFRAMES` is already open, it is skipped, preserving existing chart annotations and preventing tab clutter.
3. **Pure Native MQL5 Implementation:**
   100% DLL-free execution. Runs natively across all operating systems (Windows, Windows Server VPS, macOS, and Linux/Wine) without requiring external Windows API permissions.
4. **Diagnostic Execution Logging:**
   Outputs detailed progress reports to the MetaTrader 5 Journal log, concluding with a comprehensive statistical summary (Total Opened, Templates Applied, Duplicates Skipped).

---

## 4. Parameters Reference

### Asset Selection Settings

* `InpUseMarketWatch` (*default: `false`*): When set to `true`, the script reads and processes all active symbols currently visible in the Market Watch window.
* `InpSymbols` (*default: `"EURUSD,GBPUSD,USDJPY"`*): Comma-separated list of symbols to process when `InpUseMarketWatch = false`.
* `InpMaxSymbols` (*default: `0`*): Maximum number of symbols to process (`0` = Unlimited).

### Template Directory Settings

* `InpTemplateBaseDir` (*default: `"MyTemplates\Strategies"`*): Base subfolder path located within `MQL5\Profiles\Templates\` (e.g., `"MyTemplates"` or `"MyTemplates\Strategies"`). Leave empty (`""`) to specify root templates or full relative paths manually.

### Execution & Safety Controls

* `InpPreventDuplicates` (*default: `true`*): When enabled, skips opening a chart if the symbol and timeframe are already open in the terminal.
* `InpDelayMs` (*default: `50`*): Pause in milliseconds between chart creation events to guarantee stable asynchronous template application.

### Chart Configurations (Slots 1 to 8)

Each configuration slot allows independent timeframe and template assignment. If a template field is left empty (`""`), that slot is skipped:

* `InpPeriod_1` / `InpTemplate_1` (*default: `PERIOD_M15`, `"trend.std.tsi_vbands_vhist"`*)
* `InpPeriod_2` / `InpTemplate_2` (*default: `PERIOD_H1`, `""`*)
* `InpPeriod_3` / `InpTemplate_3` (*default: `PERIOD_CURRENT`, `""`*)
* `InpPeriod_4` / `InpTemplate_4` (*default: `PERIOD_CURRENT`, `""`*)
* `InpPeriod_5` / `InpTemplate_5` (*default: `PERIOD_CURRENT`, `""`*)
* `InpPeriod_6` / `InpTemplate_6` (*default: `PERIOD_CURRENT`, `""`*)
* `InpPeriod_7` / `InpTemplate_7` (*default: `PERIOD_CURRENT`, `""`*)
* `InpPeriod_8` / `InpTemplate_8` (*default: `PERIOD_CURRENT`, `""`*)

---

## 5. Operational Playbooks & Practical Examples

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   WORKSPACE LOADER DEPLOYMENT PLAYBOOKS                │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Tri-Timeframe Strategy Grid: M5 Execution + M15 Tactical + H1 Macro  │
│ 2. Watchlist Bulk Scanner:      Apply Master Dashboard across 20 pairs │
│ 3. Clean Re-Deployment:         Smart duplicate skip on script re-run  │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Multi-Timeframe Strategy Deployment (3-Slot Grid)

* **Objective:** Open EURUSD, GBPUSD, and USDJPY with a 3-timeframe analytical layout:
  * Slot 1: `PERIOD_M5` with `"scalp_m5"`
  * Slot 2: `PERIOD_M15` with `"trend_m15"`
  * Slot 3: `PERIOD_H1` with `"macro_h1"`
* **Configuration:**
  * `InpTemplateBaseDir = "MyTemplates\Forex"`
  * `InpSymbols = "EURUSD,GBPUSD,USDJPY"`
  * `Slot 1: PERIOD_M5  | InpTemplate_1 = "scalp_m5"`
  * `Slot 2: PERIOD_M15 | InpTemplate_2 = "trend_m15"`
  * `Slot 3: PERIOD_H1  | InpTemplate_3 = "macro_h1"`
* **Result:** In under 1 second, 9 perfectly configured charts are opened with all indicator parameters applied.

### 5.2. Market Watch Scanner Deployment

* **Objective:** Open every symbol in your Market Watch window with your master analysis template.
* **Configuration:**
  * `InpUseMarketWatch = true`
  * `InpTemplateBaseDir = "MyTemplates\Dashboards"`
  * `Slot 1: PERIOD_M15 | InpTemplate_1 = "master_dashboard"`
* **Result:** Automatically scans Market Watch and opens a dedicated M15 chart for each active instrument.

---

## 6. Diagnostic Execution Logging

Upon completion, `Workspace Loader Pro` outputs a structured audit trail to the **Experts / Journal** log:

```text
--- Starting Workspace Loader Pro: Processing 3 symbols ---
Success: Opened EURUSD [PERIOD_M15] with template 'MyTemplates\Strategies\trend.std.tsi_vbands.tpl'
Success: Opened EURUSD [PERIOD_H1] with template 'MyTemplates\Strategies\macro_trend.tpl'
Skipping duplicate: GBPUSD (PERIOD_M15) is already open.
Success: Opened GBPUSD [PERIOD_H1] with template 'MyTemplates\Strategies\macro_trend.tpl'
Success: Opened USDJPY [PERIOD_M15] with template 'MyTemplates\Strategies\trend.std.tsi_vbands.tpl'
Success: Opened USDJPY [PERIOD_H1] with template 'MyTemplates\Strategies\macro_trend.tpl'
--- Workspace Loader Pro Completed: 5 charts opened, 5 templates applied, 1 skipped duplicates ---
