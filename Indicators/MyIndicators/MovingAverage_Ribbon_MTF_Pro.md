# Moving Average Ribbon MTF Professional

## 1. Summary (Introduction)

The `MovingAverage_Ribbon_MTF_Pro` is an exceptionally powerful and flexible multi-timeframe (MTF) analysis tool. It elevates the concept of a moving average ribbon by allowing the user to configure not just the period and type, but also the **source timeframe for each of the four lines independently**.

This unique capability allows traders to construct a "multi-dimensional" view of the market on a single chart. For example, one can display a long-term trend line from the Daily timeframe, a medium-term line from H4, and two short-term lines from H1, all overlaid on an M15 chart for precise entry timing.

The indicator provides complete control over:

* **Timeframe** for each of the 4 lines.
* **Period** for each of the 4 lines.
* **MA Type** (SMA, EMA, SMMA, LWMA) for each of the 4 lines.
* **Price Source** (Standard or Heikin Ashi).

## 2. Mathematical Foundations and Calculation Logic

The indicator is a "meta-indicator" that performs four independent MTF moving average calculations and displays them together. The logic for each line follows the standard MTF process:

1. **Fetch Higher Timeframe Data:** For each of the four lines, the indicator retrieves the OHLC price data for its user-selected timeframe.
2. **Calculate the Moving Average:** The chosen moving average type is calculated on its corresponding timeframe's price data.
3. **Project to Current Chart:** All four calculated MTF moving average series are then mapped to the current chart, creating four distinct "step-like" lines.

The power of the indicator comes from the visual relationship between these lines originating from different dimensions of market time.

## 3. MQL5 Implementation Details

This indicator is built on a robust, `iCustom()`-free, and highly modular "multi-engine" architecture to handle its complexity.

* **Specialized MTF Engine (`Single_MA_MTF_Calculator.mqh`):** We first created a dedicated, reusable engine whose sole responsibility is to calculate one single moving average on one specific timeframe.

* **"Manager" Calculator (`MovingAverage_Ribbon_MTF_Calculator.mqh`):** The main engine for this ribbon indicator uses the composition design pattern. It **contains four independent instances** of the `CSingleMAMTFCalculator`.
  * The main engine acts as a "manager," delegating the complete calculation of each line to one of the specialized single-line calculators.
  * This architecture perfectly separates concerns, ensuring the code is clean, stable, and easy to maintain, despite the indicator's complexity.

* **No External Dependencies:** The entire calculation is self-contained. It directly fetches the required higher-timeframe price data using built-in `Copy...` functions, making the indicator fully portable and robust.

## 4. Parameters

The indicator's inputs are organized into four groups, one for each moving average line, providing full control.

* **MA 1-4 Settings:**
  * **`InpTimeframe1` - `InpTimeframe4`:** The source timeframe for each line. `PERIOD_CURRENT` will use the chart's active timeframe.
  * **`InpPeriod1` - `InpPeriod4`:** The lookback period for each line.
  * **`InpMAType1` - `InpMAType4`:** The MA type (SMA, EMA, SMMA, LWMA) for each line.
* **Price Source:**
  * **`InpSourcePrice`:** The source price for all calculations (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The MTF Ribbon is an advanced tool for building a comprehensive view of the market's trend structure.

* **Trend Confirmation and Confluence:** The primary use is to identify strong trends where multiple timeframes are aligned. A high-probability uptrend is in place when the price is above all four ribbon lines, and the lines themselves are ordered logically (e.g., H4 MA below H1 MA, which is below M15 MA).

* **Dynamic Support/Resistance Zones:** The space between two moving averages from different timeframes creates a powerful dynamic support or resistance "zone." For example, in an uptrend, the area between the H1 MA and the H4 MA can act as a major pullback zone for high-probability long entries.

* **Building a Complete Strategy (Example):** A trader could configure the ribbon as follows:
  * **MA 4 (Slowest):** `EMA(50)` on `D1` (Daily) - The overall market bias.
  * **MA 3:** `EMA(50)` on `H4` - The major trend direction.
  * **MA 2:** `EMA(21)` on `H1` - The medium-term trend and primary pullback zone.
  * **MA 1 (Fastest):** `EMA(8)` on `M15` - The short-term trend and entry trigger.
  * **Trade Logic:** Look for long entries on the M15 chart only when the price is above the D1, H4, and H1 MAs. An entry could be triggered when the price pulls back to the H1 EMA zone and then bounces, or when the M15 EMA crosses back up through a slightly slower MA.
