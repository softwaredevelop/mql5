# MAMA MTF Professional

## 1. Summary (Introduction)

The MAMA MTF Pro is a multi-timeframe (MTF) version of John Ehlers' highly advanced MESA Adaptive Moving Average system. This indicator calculates the MAMA and its companion FAMA line on a **higher, user-selected timeframe** and projects them onto the current, lower-timeframe chart.

This provides a powerful, smoothed-out view of the dominant, higher-level trend, allowing traders to use the MTF MAMA/FAMA lines as a broad, dynamic zone of support and resistance. The crossover signals from the higher timeframe, known for being exceptionally resistant to whipsaws, can be used to define the primary market bias.

The indicator is highly versatile: if the user selects `PERIOD_CURRENT` as the timeframe, it functions identically to the standard `MAMA_Pro` indicator.

## 2. Mathematical Foundations and Calculation Logic

The underlying calculation is identical to the standard MAMA. It is an adaptive moving average where the smoothing factor (`alpha`) is dynamically adjusted based on the **rate of change of the market's phase**, measured on the **higher timeframe**.

### Calculation Steps (Algorithm)

1. **Fetch Higher Timeframe Data:** The indicator first retrieves the OHLC price data for the user-selected higher timeframe.
2. **Calculate MAMA and FAMA on HTF:** The full, multi-stage MAMA/FAMA algorithm (including cycle measurement, phase calculation, and adaptive alpha) is executed using the higher timeframe's price data.
3. **Project to Current Chart:** The calculated higher-timeframe MAMA and FAMA values are then mapped to the current chart. This creates "step-like" lines where each value from the higher timeframe is held constant for the duration of its corresponding bars on the lower timeframe.

## 3. MQL5 Implementation Details

* **Self-Contained and Robust:** This indicator is fully self-contained and does not depend on any external indicator files (`iCustom`). It directly fetches the required higher-timeframe price data and uses the included `MAMA_Calculator.mqh` engine for all calculations.
* **Modular Calculation Engine (`MAMA_Calculator.mqh`):** The indicator reuses the exact same, proven calculation engine as the standard `MAMA_Pro`, ensuring mathematical consistency.
* **Optimized Incremental Calculation:**
    Unlike basic MTF indicators that download and recalculate the entire higher-timeframe history on every tick, this indicator employs a sophisticated incremental algorithm.
  * **HTF State Tracking:** It tracks the calculation state of the higher timeframe separately (`htf_prev_calculated`).
  * **Persistent Buffers:** The internal buffers for the higher timeframe (`BufferMAMA_HTF_Internal`) are maintained globally, preserving the complex recursive state of the MAMA algorithm between ticks.
  * **Efficient Mapping:** The projection loop only updates the bars corresponding to the new data, drastically reducing CPU usage.
  * This results in **O(1) complexity** per tick, ensuring the indicator remains lightweight even when running on multiple charts simultaneously.
* **Dual-Mode Logic:** The `OnCalculate` function contains a smart branching logic.
  * If a higher timeframe is selected, it performs the optimized MTF data fetching and projection process.
  * If the current timeframe is selected, it bypasses the MTF logic and functions identically to the standard `MAMA_Pro`, calculating directly on the current chart's data for maximum efficiency.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The higher timeframe on which the MAMA/FAMA will be calculated. If set to `PERIOD_CURRENT`, the indicator will run on the current chart's timeframe.
* **Fast Limit (`InpFastLimit`):** The maximum possible value for the adaptive `alpha`. Ehlers' recommended value is **0.5**.
* **Slow Limit (`InpSlowLimit`):** The minimum possible value for the adaptive `alpha`. Ehlers' recommended value is **0.05**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The MTF version of the MAMA/FAMA system is primarily a **high-level trend and regime filter**.

* **Defining the Primary Trend:** The state of the higher-timeframe lines provides a clear, low-noise view of the dominant trend.
  * If the **red MTF MAMA is above the blue MTF FAMA**, the primary trend is considered **bullish**. Traders should focus on buying opportunities on their trading timeframe.
  * If the **red MTF MAMA is below the blue MTF FAMA**, the primary trend is considered **bearish**. Traders should focus on selling opportunities.
* **Dynamic Support & Resistance Zone:** The space between the MTF MAMA and MTF FAMA lines can be viewed as a broad, dynamic zone of support or resistance.
  * In an uptrend, a pullback of the price on the lower timeframe into or near this MAMA/FAMA zone can present a high-probability entry point for a long position.
  * In a downtrend, a rally into this zone can present a high-probability short entry.
* **Filtering Lower Timeframe Signals:** Use the state of the MAMA MTF to filter signals from faster, lower-timeframe indicators. For example, only take buy signals from a standard Stochastic or RSI when the MTF MAMA is above the MTF FAMA.
