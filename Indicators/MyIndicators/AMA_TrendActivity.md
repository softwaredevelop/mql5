# AMA Trend Activity

## 1. Summary (Introduction)

The AMA Trend Activity is a custom-built "meta-indicator" designed to measure the directional strength and activity of the **Adaptive Moving Average (AMA)**. While the AMA line itself shows the trend, this oscillator quantifies _how trendy_ the market is according to the AMA's behavior, specifically its rate of change relative to volatility.

Developed as part of our indicator toolkit, its primary purpose is to act as a **trend filter**. It generates high values when the AMA is moving decisively in one direction (indicating an efficient, trending market) and low values when the AMA line flattens out (indicating a sideways, noisy market). It helps traders to visually distinguish between trending and non-trending environments.

## 2. Mathematical Foundations and Calculation Logic

This indicator analyzes the behavior of two underlying indicators, AMA and ATR, to produce a final, normalized oscillator.

### Required Components

- **AMA:** The underlying adaptive moving average. Its slope is the primary input.
- **ATR (Average True Range):** Used as a normalization factor to make the indicator's output comparable across different instruments and timeframes.
- **Smoothing Period:** A final smoothing period for the oscillator output.

### Calculation Steps (Algorithm)

1. **Calculate AMA:** First, the standard Kaufman's AMA is calculated for the chart based on its parameters.

2. **Calculate ATR:** Separately, the standard Wilder's ATR is calculated.

3. **Calculate Raw Activity:** For each bar, the indicator measures the rate of change (slope) of the AMA line and normalizes it by the market's current volatility (ATR). This produces a raw, unbounded value representing the trend's relative strength.
   $\text{Raw Activity}_i = \frac{\text{Abs}(\text{AMA}_i - \text{AMA}_{i-1})}{\text{ATR}_i}$

4. **Normalize with Arctan:** To solve the problem of scale across different timeframes, the `Raw Activity` value is passed through the inverse tangent (`Arctan`) function and then scaled to a consistent `0..1` range. The `Arctan` function elegantly maps any positive input into a predictable range, making the indicator robust on any timeframe.
   $\text{Scaled Activity}_i = \frac{\text{Arctan}(\text{Raw Activity}_i)}{\pi/2}$

5. **Final Smoothing:** The `Scaled Activity` values are smoothed with a Simple Moving Average (SMA) to create the final, plotted histogram.
   $\text{Final Activity}_i = \text{SMA}(\text{Scaled Activity}, \text{Smoothing Period})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a completely self-contained indicator that internally calculates all its required components based on our established robust principles.

- **Stability via Full Recalculation:** The indicator employs a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Internal Calculators:** The indicator does not use any external handles. It contains the full, robust, and manually implemented logic for calculating both the **AMA** and the **ATR**. All recursive calculations are carefully initialized to prevent floating-point overflows.

- **Robust Normalization:** The use of the `MathArctan` function for normalization is a key feature. It ensures that the indicator's output remains consistent and comparable across all instruments and timeframes, from M1 to Weekly.

- **Optimized Visualization:** The indicator's vertical scale is programmatically set to a `0.0` to `0.5` range. Our analysis showed that the vast majority of significant signals occur within this range. This "zooms in" on the most relevant area of activity, making the visual output much clearer and easier to interpret.

- **Heikin Ashi Variant (`AMA_TrendActivity_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but all its inputs (AMA and ATR) are derived from the smoothed Heikin Ashi price data.

## 4. Parameters

- **AMA Settings:**
  - `InpAmaPeriod`: The period for the AMA's Efficiency Ratio.
  - `InpFastEmaPeriod`: The "fast" period for the AMA's scaling.
  - `InpSlowEmaPeriod`: The "slow" period for the AMA's scaling.
  - `InpAppliedPrice`: The source price for the underlying AMA.
- **Activity Calculation Settings:**
  - `InpAtrPeriod`: The period for the ATR used in normalization.
  - `InpSmoothingPeriod`: The period for the final SMA smoothing of the oscillator.

## 5. Usage and Interpretation

- **Trend Filter:** This is the indicator's primary function. A trader can establish a threshold (e.g., 0.1 or 0.2).
  - **Activity > Threshold:** The market is considered to be in a **trending phase**. Trend-following strategies are more likely to be effective.
  - **Activity < Threshold:** The market is considered to be in a **ranging or consolidating phase**. Mean-reversion strategies may be more appropriate.
- **Identifying Trend Exhaustion:** A sharp decline in the activity histogram after a strong trend can signal that momentum is waning and the trend may be nearing exhaustion or entering a consolidation phase.
- **Confirming Breakouts:** A spike in the activity histogram accompanying a price breakout from a range can provide strong confirmation that the breakout has momentum behind it.
