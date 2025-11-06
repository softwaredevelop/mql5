# Trader's Dynamic Index (TDI) Professional

## 1. Summary (Introduction)

The Trader's Dynamic Index (TDI), developed by Dean Malone, is a comprehensive, "all-in-one" market analysis tool. It is a hybrid indicator that builds upon the Relative Strength Index (RSI), smoothing it with multiple moving averages and enveloping it in volatility bands to provide a simultaneous view of trend, momentum, and volatility.

Our `TDI_Pro` implementation is a unified, professional version that allows the underlying RSI calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The TDI is constructed in a layered, sequential process.

### Required Components

* **RSI Period:** The lookback period for the base RSI.
* **Price Line Period:** The period for the first, fastest moving average.
* **Signal Line Period:** The period for the second, slower moving average.
* **Base Line Period:** The period for the third, slowest moving average.
* **Bands Deviation:** The standard deviation multiplier.
* **Source Price:** The price series for the initial RSI calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Base RSI:** First, a standard Wilder's RSI is calculated.
2. **Calculate the RSI Price Line (Fast Line):** The base RSI line is smoothed using a **Simple Moving Average (SMA)** with the `Price Line Period` (default 2).
    * $\text{Price Line}_t = \text{SMA}(\text{RSI}, 2)_t$
3. **Calculate the Trade Signal Line (Slow Line):** The **Price Line** is smoothed again using an SMA with the `Signal Line Period` (default 7).
    * $\text{Signal Line}_t = \text{SMA}(\text{Price Line}, 7)_t$
4. **Calculate the Market Base Line (Trend Line):** The **Price Line** is smoothed a third time, using a `Base Line Period` SMA (default 34).
    * $\text{Base Line}_t = \text{SMA}(\text{Price Line}, 34)_t$
5. **Calculate the Volatility Bands:** Bollinger Bands are calculated around the **Base Line**. The standard deviation is calculated on the **base RSI**, using the `Base Line Period`.
    * $\text{StdDev}_t = \text{StandardDeviation}(\text{RSI}, \text{Base Line Period})_t$
    * $\text{Upper Band}_t = \text{Base Line}_t + (\text{Bands Deviation} \times \text{StdDev}_t)$
    * $\text{Lower Band}_t = \text{Base Line}_t - (\text{Bands Deviation} \times \text{StdDev}_t)$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a robust, definition-true representation of the TDI, built with a modular and stable architecture.

* **Self-Contained Calculation Engine (`TDI_Calculator.mqh`):**
    The entire multi-stage calculation logic is encapsulated within a single, dedicated include file. The calculator first computes the base Wilder's RSI and then sequentially calculates all TDI components (Price Line, Signal Line, Base Line, and Volatility Bands) in an efficient, single-pass process.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CTDICalculator`, performs the full TDI calculation on a given source price.
  * A derived class, `CTDICalculator_HA`, inherits all the complex logic and only overrides the initial data preparation step (`PreparePriceSeries`) to use smoothed Heikin Ashi prices as its input. This object-oriented approach eliminates code duplication.

* **Stability via Full Recalculation:** The TDI's calculation is highly state-dependent. To ensure perfect accuracy, our implementation employs a "brute-force" **full recalculation** on every tick.

## 4. Parameters

* **RSI Period (`InpRsiPeriod`):** The lookback period for the base RSI. Default is `13`.
* **Price Line Period (`InpPriceLinePeriod`):** The smoothing period for the fast (green) line. Default is `2`.
* **Signal Line Period (`InpSignalLinePeriod`):** The smoothing period for the slow (red) signal line. Default is `7`.
* **Base Line Period (`InpBaseLinePeriod`):** The smoothing period for the yellow trend line and the volatility bands. Default is `34`.
* **Bands Deviation (`InpBandsDeviation`):** The standard deviation multiplier for the blue volatility bands. The standard value is `1.618`.
* **Source Price (`InpSourcePrice`):** The price data for the base RSI calculation. This unified dropdown allows you to select from all standard and Heikin Ashi price types.

## 5. Suggested Settings for the RSI Indicator Family

To use the `RSI_Pro`, `VIDYA_RSI_Pro`, and `TDI_Pro` as a coherent system, their parameters should be synchronized. The core of the system is the base RSI Period. Here are two suggested configurations:

| Indicator           | Parameter             | **Standard Setting (13)** | **Fast Setting (8)** |
| ------------------- | --------------------- | :-----------------------: | :------------------: |
| **RSI_Pro**         | `InpPeriodRSI`        |            **13**             |         **8**          |
|                     |                       |                           |                      |
| **VIDYA_RSI_Pro**   | `InpPeriodRSI`        |            **13**             |         **8**          |
|                     | `InpPeriodEMA`        |            `20`             |         `12`         |
|                     |                       |                           |                      |
| **TDI_Pro** (RSI)   | `InpRsiPeriod`        |            **13**             |         **8**          |
|                     | `InpPriceLinePeriod`  |             `2`             |         `2`          |
|                     | `InpSignalLinePeriod` |             `7`             |         `5`          |
|                     | `InpBaseLinePeriod`   |            `34`             |         `34`         |
|                     | `InpBandsDeviation`   |           `1.618`           |       `1.618`        |

### Rationale for Settings

* **Standard Setting (13):** This is a balanced, medium-term configuration suitable for most timeframes (e.g., H1, H4). It provides a good compromise between responsiveness and signal smoothness. The TDI parameters are the classic, industry-standard values designed for this RSI period.
* **Fast Setting (8):** This is a more sensitive configuration, ideal for lower timeframes (e.g., M5, M15). The `VIDYA EMA Period` and `TDI Signal Line Period` are reduced to better track the faster, more volatile RSI signal. The `TDI Base Line Period` is kept at `34` to maintain a stable long-term context.

## 6. Usage and Interpretation

* **Trend Direction (Market Base Line - Yellow):** The yellow line indicates the overall medium-term trend.
* **Momentum (Price Line - Green):** The green line shows the short-term momentum.
* **Entry Signals (Green/Red Crossover):** The primary entry signal is the crossover of the green Price Line and the red Signal Line.
* **Volatility (Volatility Bands - Blue):** When the bands tighten (squeeze), it indicates low volatility. When they widen, it confirms a strong move is underway.
* **Caution:** The TDI is most effective when its signals are confirmed by price action and analysis of the market structure on the main chart.
