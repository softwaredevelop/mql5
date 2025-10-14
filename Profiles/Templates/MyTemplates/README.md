# Chart Templates (`MyTemplates/`)

To streamline market analysis, we use a standardized set of chart templates (`.tpl`). Each template is a pre-configured workspace designed for a specific trading style or analytical purpose.

## Naming Convention

Our templates follow a consistent, hierarchical naming convention to ensure they are easy to identify and manage:

`[Focus].[ChartType].[System].[Variation].tpl`

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
  - `supertrend`, `murrey`, `vwap`, `bands`, `tdi`, etc.

- **`[Variation]`** (Optional): A descriptor for the template's complexity or specific use case.
  - `light`: A minimal set of essential indicators.
  - `full` or `suite`: A comprehensive set of indicators for deep analysis.
  - `v1`, `v2`, etc.

## Core Template Examples

| Template Name | Primary Purpose | Core Indicators |
| :--- | :--- | :--- |
| **`trend.ha.supertrend_adx.tpl`** | Mid-term trend-following and swing trading. | `Chart_HeikinAshi`, `Supertrend_Pro`, `ADX_Pro`, `McGinleyDynamic_Pro` |
| **`reversal.std.bb_stoch.tpl`** | Mean-reversion and range trading. | `Bollinger_Bands_Pro`, `StochasticSlow_Pro`, `Bollinger_Band_Width_Pro`, `SymmetricWMA_Pro` |
| **`scalp.std.vwap_momentum.tpl`**| Intraday trading around institutional benchmarks. | `VWAP_Pro`, `Session_Analysis_Pro`, `TSI_Pro`, `ATR_Pro` |
| **`divergence.ha.uo_mfi.tpl`** | Identifying trend exhaustion and reversals via divergence. | `Chart_HeikinAshi`, `UltimateOscillator_Pro`, `MFI_Pro`, `FisherTransform_Pro` |
