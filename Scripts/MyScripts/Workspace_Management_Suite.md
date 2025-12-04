# Workspace Management Suite

## 1. Summary (Introduction)

Managing a professional trading environment in MetaTrader 5 can be tedious. Opening dozens of charts, applying specific templates, and switching between different asset lists (e.g., Forex vs. Indices) manually takes valuable time away from analysis.

Our **Workspace Management Suite** is a set of three integrated scripts designed to automate this entire workflow. They allow you to **audit, clean, and rebuild** your workspace in seconds.

The suite consists of:

1. **`List_Open_Charts`**: Audits your current workspace.
2. **`Close_Charts_By_Symbol`**: Surgically removes specific charts or clears the workspace.
3. **`Workspace_Loader_Pro`**: Instantly builds complex, multi-chart layouts for lists of symbols.

## 2. The Workflow

These tools are designed to work together.

### Scenario: Switching from "Forex Morning" to "US Indices Afternoon"

1. **Audit (Optional):** Run `List_Open_Charts` to see what you currently have open and get a clean list of symbols in the Experts log.
2. **Clean:** Run `Close_Charts_By_Symbol`.
    * Select `Close All` to wipe the slate clean.
    * Or paste a list (e.g., "EURUSD,GBPUSD") to close only specific pairs.
3. **Build:**
    * Set up your Market Watch with the US Indices you want to trade (US500, US30, USTEC).
    * Run `Workspace_Loader_Pro`.
    * Enable `Use Market Watch`.
    * Load a `.set` file that defines your strategy (e.g., "Trend Layout": H1 Trend Template + M5 Scalp Template).
    * Click OK. The script will open all the charts for all the indices with your exact strategy applied.

## 3. Tool Reference

### A. `List_Open_Charts`

* **Purpose:** Scans all open charts in the terminal.
* **Output:** Prints a report to the "Experts" tab in the Toolbox.
  * Detailed list of every chart (ID, Symbol, Period).
  * **Comma-Separated List:** A clean string of unique symbols (e.g., `EURUSD,USDJPY,Gold`) that you can copy and paste directly into the other scripts.

### B. `Close_Charts_By_Symbol`

* **Purpose:** Closes charts programmatically.
* **Parameters:**
  * `InpSymbols`: A comma-separated list of symbols to close.
  * `InpCloseAll`: If `true`, it closes **every single chart** in the terminal. Use with caution!

### C. `Workspace_Loader_Pro`

* **Purpose:** The core builder tool. Opens multiple charts for multiple symbols with specific templates.
* **Source Selection:**
  * `InpUseMarketWatch`: If `true`, the script loads every symbol currently visible in your Market Watch window. This is the fastest way to load a whole asset class.
  * `InpSymbols`: If `Use Market Watch` is `false`, the script uses this comma-separated list.
* **Layout Configuration (Slots 1-8):**
  * You can define up to 8 different chart views for each symbol.
  * **`Period`**: The timeframe (e.g., M5, H1).
  * **`Template`**: The template file to apply (e.g., `MyTemplates\trend.ha.base.tpl`). Leave empty to skip the slot.
* **Presets:** You should save your configurations (e.g., "Scalping Setup", "Swing Setup") as `.set` files for instant access.
