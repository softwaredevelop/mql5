# Chart Templates (`MyTemplates/`)

To streamline market analysis, we use a standardized set of chart templates (`.tpl`). Each template is a pre-configured workspace designed for a specific trading style or analytical purpose.

## Naming Convention

Our templates follow a consistent, hierarchical naming convention to ensure they are easy to identify and manage:

`[Focus].[ChartType].[System].[Session].[Variation].tpl`

- **`[Focus]`**: The primary trading style or goal.
  - `trend`: For trend-following strategies.
  - `reversal`: For identifying mean-reversion opportunities.
  - `sr`: For support/resistance and structural analysis.
  - `scalp`: For short-term, intraday strategies.
  - `divergence`: For focusing on momentum divergences.

- **`[ChartType]`**: The base chart visualization.
  - `std`: Standard candlesticks.
  - `ha`: Heikin Ashi candles.

- **`[System]`**: The core indicator or concept the template is built around.
  - `vwap`, `laguerre`, `supersmoother`, `murrey`, etc.

- **`[Session]`** (Optional): Specifies the market session configuration (for templates using `Session_Analysis_Pro`).
  - `tlx_sum`: TSE + LSE + Xetra (Summer)
  - `tlx_win`: TSE + LSE + Xetra (Winter)
  - `tln_sum`: TSE + LSE + NYSE (Summer)
  - `tln_win`: TSE + LSE + NYSE (Winter)
  - `lxn`: LSE + Xetra + NYSE
  - *(Omitted if not applicable or generic)*

- **`[Variation]`** (Optional): A descriptor for the template's complexity.
  - `light`: Minimal set.
  - `full` or `suite`: A comprehensive set of indicators for deep analysis.
  - `v1`, `v2`, etc.

## Core Template Examples

| Template Name | Primary Purpose | Core Indicators |
| :--- | :--- | :--- |
| **`scalp.std.vwap.tln_sum.full.tpl`** | Intraday scalping during Summer sessions (Tokyo/London/NY). | `VWAP_Pro`, `Session_Analysis_Pro` (Summer), `StochRSI`, `SMI` |
| **`trend.ha.laguerre.lxn.suite_v1.tpl`** | Trend following focused on European/US overlap. | `Chart_HeikinAshi`, `Laguerre_Filter_Pro`, `Session_Analysis_Pro` (LSE/Xetra/NY) |
