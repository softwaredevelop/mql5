# Variable Index Dynamic Average (VIDYA) MTF Professional

## 1. Summary (Introduction)

The `VIDYA_MTF_Pro` is a multi-timeframe (MTF) version of Tushar Chande's adaptive moving average. It projects the VIDYA from a **higher, user-selected timeframe** onto the current chart.

The VIDYA adapts its speed based on the market's volatility (measured by the Chande Momentum Oscillator - CMO), making it an excellent tool for identifying the "true" trend of the higher timeframe.

## 2. Mathematical Foundations

The calculation combines an EMA with a volatility index:

1. **CMO:** Calculated on the higher timeframe to measure momentum/volatility.
2. **Alpha:** The smoothing factor is dynamically adjusted: $\alpha = \frac{2}{N+1} \times |CMO|$.
3. **VIDYA:** The recursive formula is applied to the higher timeframe data.

## 3. MQL5 Implementation Details

* **Self-Contained:** Uses direct `Copy...` functions; no external dependencies.
* **Modular Engine (`VIDYA_Calculator.mqh`):** Reuses the standard VIDYA logic.

* **Optimized Incremental Calculation (O(1)):**
  * **HTF State Tracking:** Tracks `htf_prev_calculated` to process only new bars on the higher timeframe.
  * **Persistent State:** The internal VIDYA buffer preserves the recursive value from the previous calculation step.
  * **Smart Mapping:** Projects the values to the current chart efficiently, handling the index alignment between timeframes correctly.

## 4. Parameters

* **Upper Timeframe (`InpUpperTimeframe`):** The calculation timeframe.
* **CMO Period (`InpPeriodCMO`):** Lookback for volatility measurement (Default: `9`).
* **EMA Period (`InpPeriodEMA`):** Base smoothing period (Default: `12`).
* **Applied Price (`InpSourcePrice`):** Standard or Heikin Ashi.

## 5. Usage and Interpretation

* **Trend Filter:** Price above MTF VIDYA = Bullish bias; Price below = Bearish bias.
* **Flat Line:** A flat MTF VIDYA indicates low volatility and consolidation on the higher timeframe.
* **Support/Resistance:** Due to its adaptive nature, the MTF VIDYA often hugs price action closely during trends, providing accurate dynamic support levels.
