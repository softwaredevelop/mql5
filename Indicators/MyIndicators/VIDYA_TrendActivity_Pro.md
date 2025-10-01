# VIDYA Trend Activity Professional

## 1. Summary (Introduction)

The VIDYA Trend Activity is a custom-built "meta-indicator" designed to measure the directional strength and activity of the **Variable Index Dynamic Average (VIDYA)**. While the VIDYA line itself shows the trend, this oscillator quantifies *how trendy* the market is according to the VIDYA's behavior.

Its primary purpose is to act as a **trend filter**. It generates high values when the VIDYA is moving decisively and low values when the VIDYA line flattens out.

Our `VIDYA_TrendActivity_Pro` implementation is a unified, professional version that allows all underlying calculations (both VIDYA and ATR) to be based on either **standard** or **Heikin Ashi** data.

## 2. Mathematical Foundations and Calculation Logic

This indicator analyzes the behavior of two underlying indicators, VIDYA and ATR, to produce a final, normalized oscillator.

### Required Components

* **VIDYA:** The underlying adaptive moving average. Its slope is the primary input.
* **ATR (Average True Range):** Used as a normalization factor.
* **Smoothing Period:** A final smoothing period for the oscillator output.

### Calculation Steps (Algorithm)

1. **Calculate VIDYA:** First, the standard VIDYA is calculated.
2. **Calculate ATR:** Separately, the standard Wilder's ATR is calculated.
3. **Calculate Raw Activity:** For each bar, the indicator measures the rate of change of the VIDYA line and normalizes it by the market's current volatility (ATR).
    $\text{Raw Activity}_i = \frac{\text{Abs}(\text{VIDYA}_i - \text{VIDYA}_{i-1})}{\text{ATR}_i}$
4. **Normalize with Arctan:** The `Raw Activity` value is passed through the inverse tangent (`Arctan`) function and scaled to a consistent `0..1` range.
    $\text{Scaled Activity}_i = \frac{\text{Arctan}(\text{Raw Activity}_i)}{\pi/2}$
5. **Final Smoothing:** The `Scaled Activity` values are smoothed with a Simple Moving Average (SMA).
    $\text{Final Activity}_i = \text{SMA}(\text{Scaled Activity}, \text{Smoothing Period})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Component-Based Design:** The `VIDYA_TrendActivity_Calculator` **reuses** our existing, standalone `VIDYA_Calculator.mqh` and `ATR_Calculator.mqh` modules. This eliminates code duplication and ensures consistency.

* **Object-Oriented Logic:**
  * The `CVIDYATrendActivityCalculator` base class contains pointers to the VIDYA and ATR calculator objects.
  * The Heikin Ashi version (`CVIDYATrendActivityCalculator_HA`) is achieved simply by instantiating the Heikin Ashi version of the VIDYA module (`CVIDYACalculator_HA`). The ATR calculator type is chosen dynamically based on user input.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

## 4. Parameters

* **VIDYA Settings:**
  * `InpPeriodCMO`: The period for the underlying Chande Momentum Oscillator.
  * `InpPeriodEMA`: The base period for the underlying VIDYA.
  * `InpSourcePrice`: The source price for the underlying VIDYA. This unified dropdown allows you to select from all standard and Heikin Ashi price types.
* **Activity Calculation Settings:**
  * `InpAtrPeriod`: The period for the ATR used in normalization.
  * `InpAtrSource`: Determines the source for the ATR calculation (`Standard` or `Heikin Ashi`).
  * `InpSmoothingPeriod`: The period for the final SMA smoothing of the oscillator.

## 5. Usage and Interpretation

* **Trend Filter:** This is the indicator's primary function. A trader can establish a threshold (e.g., 0.1 or 0.2).
  * **Activity > Threshold:** The market is considered to be in a **trending phase**.
  * **Activity < Threshold:** The market is considered to be in a **ranging or consolidating phase**.
* **Identifying Trend Exhaustion:** A sharp decline in the activity histogram after a strong trend can signal that momentum is waning.
* **Confirming Breakouts:** A spike in the activity histogram accompanying a price breakout can provide strong confirmation that the breakout has momentum.
