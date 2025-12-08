# Workspace Loader Pro (Script)

## 1. Summary (Introduction)

The `Workspace_Loader_Pro` is a powerful utility script designed to automate the setup of complex trading workspaces. Instead of manually opening charts, setting timeframes, and applying templates one by one, this script allows you to define a "Layout Profile" and apply it to multiple symbols instantly.

It is the ultimate time-saver for traders who monitor multiple assets using a standardized set of analysis tools (e.g., a "Trend" chart on H1 and a "Scalp" chart on M5 for every pair).

## 2. Features and Logic

* **Multi-Symbol Support:** Accepts a comma-separated list of symbols (e.g., "EURUSD, GBPUSD, USDJPY").
* **Flexible Configuration:** Provides 8 configuration slots. Each slot defines a specific **Timeframe** and **Template** to be applied.
* **Smart Execution:** The script iterates through the list of symbols and, for each symbol, opens all the charts defined in the active configuration slots.
* **Preset Capability:** The entire configuration (symbols + layout) can be saved as a standard `.set` file, allowing you to switch between different trading modes (e.g., "Morning Scalping", "Weekly Analysis") in seconds.

## 3. Parameters

* **`InpUseMarketWatch`:** If `true`, loads all symbols from the Market Watch window.
* **`InpSymbols`:** A comma-separated list of the symbols you want to load (ignored if `Use Market Watch` is true).
  * Example: `EURUSD, GBPUSD, XAUUSD, US500`
* **Chart Configuration 1 - 8:**
  * **`InpPeriod_X`:** The timeframe for the chart (e.g., `PERIOD_M15`, `PERIOD_H1`).
  * **`InpTemplate_X`:** The exact name of the template file (`.tpl`) to apply.
    * If the template is in the root `Templates` folder, just use the name (e.g., `Default.tpl`).
    * If it is in a subfolder, include the path (e.g., `MyTemplates\trend.ha.base.tpl`).
    * **Leave this field empty to disable the slot.**

## 4. Configuration & Presets

To organize your workspace layouts, we recommend saving your configurations as `.set` files using the following naming convention:

`ws.[Strategy].[Market].[Timeframe].set`

### Recommended Presets

| Preset Name | Purpose | Configuration Example |
| :--- | :--- | :--- |
| **`ws.scalp.forex.m5.set`** | **Intraday Forex Scalping.** | Symbols: `EURUSD,GBPUSD`<br>Slot 1: `M15` + Trend Template<br>Slot 2: `M5` + Scalp Template |
| **`ws.trend.indices.h1.set`** | **Swing Trading Indices.** | Symbols: `US500,DE40`<br>Slot 1: `H4` + Market Structure<br>Slot 2: `H1` + Trend Suite |
| **`ws.analysis.mixed.daily.set`** | **Daily Market Review.** | Symbols: `EURUSD,Gold,US500`<br>Slot 1: `D1` + Session Analysis (Full Day) |

## 5. Usage and Workflow

The power of this script lies in using **Presets (.set files)**.

### Creating a "Morning Scalp" Workspace

1. Open the script properties.
2. Set `InpSymbols` to your favorite pairs: `EURUSD, GBPUSD, USDJPY`.
3. **Config 1:** Set Period to `M15` and Template to `MyTemplates\trend.ha.base.tpl` (for trend context).
4. **Config 2:** Set Period to `M5` and Template to `MyTemplates\scalp.std.vwap.tln_sum.full.tpl` (for entry).
5. Click **"Save"** and name the file `ws.scalp.forex.morning.set`.

### Execution

When you start your trading day:

1. Drag the script onto any chart.
2. Click **"Load"** and select your desired workflow (e.g., `ws.scalp.forex.morning.set`).
3. Click **OK**. The script will instantly open and configure all the requested charts.
4. Use the terminal's "Tile Windows" command (Alt+R) to arrange them neatly.
