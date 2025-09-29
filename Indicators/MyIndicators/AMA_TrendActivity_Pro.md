# AMA Trend Activity Professional

## 1. Summary (Introduction)

The AMA Trend Activity is a custom-built "meta-indicator" designed to measure the directional strength and activity of the **Adaptive Moving Average (AMA)**. While the AMA line itself shows the trend, this oscillator quantifies *how trendy* the market is according to the AMA's behavior, specifically its rate of change relative to volatility.

Developed as part of our indicator toolkit, its primary purpose is to act as a **trend filter**. It generates high values when the AMA is moving decisively in one direction (indicating an efficient, trending market) and low values when the AMA line flattens out (indicating a sideways, noisy market).

Our `AMA_TrendActivity_Pro` implementation is a unified, professional version that allows all underlying calculations (both AMA and ATR) to be based on either **standard** or **Heikin Ashi** data.

## 2. Mathematical Foundations and Calculation Logic

This indicator analyzes the behavior of two underlying indicators, AMA and ATR, to produce a final, normalized oscillator.

### Required Components

* **AMA:** The underlying adaptive moving average. Its slope is the primary input.
* **ATR (Average True Range):** Used as a normalization factor to make the indicator's output comparable across different instruments and timeframes.
* **Smoothing Period:** A final smoothing period for the oscillator output.

### Calculation Steps (Algorithm)

1. **Calculate AMA:** First, the standard Kaufman's AMA is calculated based on its parameters.

2. **Calculate ATR:** Separately, the standard Wilder's ATR is calculated.

3. **Calculate Raw Activity:** For each bar, the indicator measures the rate of change (slope) of the AMA line and normalizes it by the market's current volatility (ATR). This produces a raw, unbounded value representing the trend's relative strength.
    $\text{Raw Activity}_i = \frac{\text{Abs}(\text{AMA}_i - \text{AMA}_{i-1})}{\text{ATR}_i}$

4. **Normalize with Arctan:** To solve the problem of scale across different timeframes, the `Raw Activity` value is passed through the inverse tangent (`Arctan`) function and then scaled to a consistent `0..1` range. The `Arctan` function elegantly maps any positive input into a predictable range, making the indicator robust on any timeframe.
    $\text{Scaled Activity}_i = \frac{\text{Arctan}(\text{Raw Activity}_i)}{\pi/2}$

5. **Final Smoothing:** The `Scaled Activity` values are smoothed with a Simple Moving Average (SMA) to create the final, plotted histogram.
    $\text{Final Activity}_i = \text{SMA}(\text{Scaled Activity}, \text{Smoothing Period})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design pattern to ensure stability, reusability, and maintainability. The logic is separated into a main indicator file and a dedicated calculator engine.

* **Modular Calculator Engine (`AMA_TrendActivity_Calculator.mqh`):**
    All core calculation logic is encapsulated within a reusable include file. This separates the complex, five-step mathematical process from the indicator's user interface and buffer management.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CActivityCalculator`, handles the **entire shared calculation chain** (AMA, ATR, Raw Activity, Arctan, and SMA smoothing).
  * A derived class, `CActivityCalculator_HA`, inherits from the base class and **overrides** only one specific function: the preparation of all source data. Its sole responsibility is to calculate Heikin Ashi candles and provide the resulting HA data to the base class's calculation pipeline for both the AMA and ATR components. This is a clean and efficient use of polymorphism.

* **Simplified Main Indicator (`AMA_TrendActivity_Pro.mq5`):**
    The main indicator file is now extremely clean. Its primary roles are:
    1. Handling user inputs (`input` variables).
    2. Instantiating the correct calculator object (`CActivityCalculator` or `CActivityCalculator_HA`) in `OnInit()` based on the user's choice.
    3. Delegating the entire calculation process to the calculator object with a single call in `OnCalculate()`.

* **Stability via Full Recalculation:** We use a full recalculation on every tick. For a complex, multi-stage, and recursive indicator like this, the "brute-force" approach is the most robust method.

## 4. Parameters (`AMA_TrendActivity_Pro.mq5`)

* **AMA Settings:**
  * `InpAmaPeriod`: The period for the AMA's Efficiency Ratio.
  * `InpFastEmaPeriod`: The "fast" period for the AMA's scaling.
  * `InpSlowEmaPeriod`: The "slow" period for the AMA's scaling.
  * `InpSourcePrice`: The source price for the underlying AMA. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Activity Calculation Settings:**
  * `InpAtrPeriod`: The period for the ATR used in normalization.
  * `InpSmoothingPeriod`: The period for the final SMA smoothing of the oscillator.

## 5. Usage and Interpretation

* **Trend Filter:** This is the indicator's primary function. A trader can establish a threshold (e.g., 0.1 or 0.2).
  * **Activity > Threshold:** The market is considered to be in a **trending phase**. Trend-following strategies are more likely to be effective.
  * **Activity < Threshold:** The market is considered to be in a **ranging or consolidating phase**. Mean-reversion strategies may be more appropriate.
* **Identifying Trend Exhaustion:** A sharp decline in the activity histogram after a strong trend can signal that momentum is waning and the trend may be nearing exhaustion or entering a consolidation phase.
* **Confirming Breakouts:** A spike in the activity histogram accompanying a price breakout from a range can provide strong confirmation that the breakout has momentum behind it.
