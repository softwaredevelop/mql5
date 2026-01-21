# Indicator Presets Reference (`Presets/`)

This document outlines the naming convention and organization for Indicator Preset files (`.set`). These files store specific input parameter configurations for our indicators, allowing traders to quickly switch between different trading styles (e.g., Scalping vs. Swing) or restore default settings.

## Naming Convention

The naming structure is designed to be intuitive, grouping presets first by the indicator they belong to, and then by their intended purpose.

`[IndicatorName].[Strategy].[Detail].set`

### 1. `[IndicatorName]`

The base name of the indicator. This ensures that presets are automatically grouped together in the file explorer.

* `Laguerre_ACS`
* `MACD_Pro`
* `TSI_Pro`
* `Cyber_Cycle`

### 2. `[Strategy]`

The primary trading style or configuration category.

* **`default`**: The standard, recommended starting parameters (often Ehlers' defaults).
* **`scalp`**: Tuned for high sensitivity and fast reaction (e.g., lower periods, lower gamma).
* **`swing`** / **`trend`**: Tuned for smoothness and noise reduction (e.g., higher periods, higher gamma).
* **`ha`**: Specifically configured for use with Heikin Ashi price sources (e.g., may use different thresholds).

### 3. `[Detail]` (Optional)

Specific technical details that distinguish this preset from others in the same strategy.

* `fast`, `slow`
* `dema`, `tema` (if using specific MA types)
* `gamma02`, `gamma08`
* `conservative`, `aggressive`

## Examples

### Laguerre Family

| Filename | Description |
| :--- | :--- |
| **`Laguerre_ACS.default.set`** | Standard adaptive settings. |
| **`Laguerre_Filter.scalp.gamma02.set`** | Very fast filter (Gamma 0.2) for M1/M5 scalping. |
| **`Laguerre_RSI.swing.smooth.set`** | Smoother RSI (Gamma 0.8) for H4/D1 trend trading. |

### MACD Pro Family

| Filename | Description |
| :--- | :--- |
| **`MACD_Pro.default.set`** | Classic 12, 26, 9 EMA settings. |
| **`MACD_Pro.scalp.dema.set`** | Uses DEMA (Double EMA) for all lines to reduce lag significantly. |
| **`MACD_Pro.trend.tema.set`** | Uses TEMA (Triple EMA) for ultra-smooth trend following. |

### TSI Family

| Filename | Description |
| :--- | :--- |
| **`TSI_Pro.default.set`** | Classic 25, 13, 13 EMA settings. |
| **`TSI_Pro.ha.smooth.set`** | Configured for Heikin Ashi source with slightly longer periods. |

## Usage

1. Open the **Indicator Properties** window (double-click the indicator on the chart).
2. Go to the **Inputs** tab.
3. Click the **Load** button.
4. Navigate to the `Presets` folder and select the desired `.set` file.
