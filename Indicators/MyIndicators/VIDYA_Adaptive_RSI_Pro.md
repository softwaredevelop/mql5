# VIDYA Adaptive RSI Pro

## 1. Summary (Introduction)

The **VIDYA Adaptive RSI Pro** is a cutting-edge moving average that represents the pinnacle of adaptive filtering technology. It combines Tushar Chande's **VIDYA (Variable Index Dynamic Average)** concept with our proprietary **Adaptive RSI**.

* **Standard VIDYA:** Adjusts its smoothing based on a fixed-period volatility indicator (usually CMO or standard RSI).
* **This Indicator:** Adjusts its smoothing based on an **Adaptive RSI**, whose own period dynamically changes based on market efficiency (ER).

This creates a "doubly adaptive" system: the volatility measure itself adapts to the market structure, which in turn fine-tunes the moving average. The result is a trend-following line that offers an exceptional balance between responsiveness during breakouts and stability during consolidation.

## 2. Mathematical Foundations

The calculation involves a chain of adaptive logic:

1. **Market Efficiency (ER):** First, the Efficiency Ratio is calculated to determine if the market is trending or noisy.
2. **Adaptive RSI (ARSI):** The lookback period of the RSI is adjusted based on the ER.
    * High ER (Trend) -> Shorter RSI Period (Faster).
    * Low ER (Noise) -> Longer RSI Period (Smoother).
3. **Volatility Factor (k):** The ARSI value is normalized to determine the volatility factor.
    * $V = \frac{|ARSI - 50|}{50}$
    * $V$ ranges from 0 (when ARSI is 50) to 1 (when ARSI is 0 or 100).
4. **VIDYA Calculation:** The final moving average is calculated using this dynamic factor.
    * $\text{VIDYA}_t = \alpha \times V \times \text{Price}_t + (1 - \alpha \times V) \times \text{VIDYA}_{t-1}$
    * Where $\alpha = \frac{2}{\text{EMA Period} + 1}$.

## 3. MQL5 Implementation Details

* **Composite Architecture:** The calculator (`VIDYA_Adaptive_RSI_Calculator.mqh`) internally hosts an instance of the `CAdaptiveRSICalculator`. This ensures that the complex logic of the Adaptive RSI is reused efficiently, not duplicated.
* **O(1) Incremental Calculation:** Despite the complexity, the indicator is optimized to process only new bars, ensuring minimal CPU load.
* **Heikin Ashi Integration:** Full support for Heikin Ashi price data for both the VIDYA calculation and the internal Adaptive RSI.

## 4. Parameters

### Adaptive RSI Settings (The "Engine")

* **Pivotal Period:** The base period for the RSI. Default is `14`.
* **Vola Short/Long:** Periods used for the Efficiency Ratio calculation.
* **Adaptive Source:** Selects whether the ER is calculated on Standard or Heikin Ashi prices.

### VIDYA Settings (The "Output")

* **EMA Period:** The base smoothing period for the VIDYA. Default is `20`.
  * This sets the "maximum speed" of the average. The actual speed will always be slower than or equal to a standard EMA of this period, depending on volatility.
* **Price Source:** Selects the input price for the moving average itself.

## 5. Usage and Interpretation

### Trend Filter (Primary Use)

This indicator is an excellent trend filter because it flattens out significantly during ranging markets, avoiding the "whipsaws" common with standard EMAs.

* **Bullish:** Price is above the VIDYA line, and the line is sloping up.
* **Bearish:** Price is below the VIDYA line, and the line is sloping down.

### Dynamic Support/Resistance

Because the VIDYA adapts to volatility, it often acts as a very accurate dynamic support level in uptrends (and resistance in downtrends). Price pullbacks often touch the VIDYA line before resuming the trend.

### Breakout Confirmation

When the VIDYA line suddenly changes slope from flat to steep, it confirms that a breakout is supported by expanding volatility and momentum.
