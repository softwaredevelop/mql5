# Laguerre RSI Professional

## 1. Summary (Introduction)

> **Part of the Laguerre Indicator Family**
>
> This indicator is a member of a family of tools based on John Ehlers' Laguerre filter. Each member utilizes the filter's extremely low-lag and smooth characteristics to analyze different aspects of market behavior.
>
> * **Laguerre Filter:** A fast, responsive moving average.
> * **Laguerre RSI:** A smooth, noise-filtered momentum oscillator.

The Laguerre RSI, developed by John Ehlers, is a sophisticated and modern version of the classic Relative Strength Index (RSI). Its core innovation is the use of a **Laguerre filter** to smooth the price data before the RSI calculation is applied.

The result is an oscillator that is exceptionally **smooth** and produces significantly less noise and fewer "whipsaws" than a traditional RSI. Despite its smoothness, it remains highly responsive to changes in market momentum.

Our `Laguerre_RSI_Pro` implementation is a unified, professional version that includes an **optional, fully customizable signal line** and allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The indicator's logic is a multi-stage process: first, the price is filtered, then an RSI-like formula is applied, and finally, an optional signal line is calculated.

### Required Components

* **Gamma (γ):** A coefficient that controls the Laguerre filter's speed.
* **Signal Period (S):** The period for the signal line's moving average.
* **Source Price (P):** The price series for the calculation.

### Calculation Steps (Algorithm)

The calculation is highly recursive, relying on the state of four internal filter components from the previous bar (`L0`, `L1`, `L2`, `L3`).

1. **Initialize Filter:** For the first bar, all `L` components are initialized with the current price.
2. **Calculate Laguerre Filter Components:** For each subsequent bar `i`, the filter components are updated based on the previous bar's values:
    * $L0_i = (1 - \gamma) \times P_i + \gamma \times L0_{i-1}$
    * $L1_i = -\gamma \times L0_i + L0_{i-1} + \gamma \times L1_{i-1}$
    * $L2_i = -\gamma \times L1_i + L1_{i-1} + \gamma \times L2_{i-1}$
    * $L3_i = -\gamma \times L2_i + L2_{i-1} + \gamma \times L3_{i-1}$
3. **Calculate RSI-like Sums:** The "up" and "down" sums (`cu` and `cd`) are calculated from the differences between the filter components:
    * `cu = 0`, `cd = 0`
    * If $L0_i \ge L1_i$, then `cu += L0_i - L1_i`, else `cd += L1_i - L0_i`
    * If $L1_i \ge L2_i$, then `cu += L1_i - L2_i`, else `cd += L2_i - L1_i`
    * If $L2_i \ge L3_i$, then `cu += L2_i - L3_i`, else `cd += L3_i - L2_i`
4. **Calculate Final Laguerre RSI Value:**
    * $\text{Laguerre RSI}_i = 100 \times \frac{cu}{cu + cd}$
    * The final value is clamped to the range to handle minor floating-point overflows.

## 3. MQL5 Implementation Details

* **Modular "Family" Architecture:** The core Laguerre filter calculation is encapsulated in a central `Laguerre_Engine.mqh` file. This engine is a **stateful class** that correctly maintains the state of its internal recursive components, ensuring a stable and accurate foundation. The `Laguerre_RSI_Calculator.mqh` is a thin adapter that uses this stable engine to generate the RSI.
* **Heikin Ashi Integration:** An inherited `CLaguerreEngine_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** We employ a full recalculation within `OnCalculate` for maximum stability.
* **Value Clamping:** The final calculated value is mathematically clamped to the 0-100 range.

## 4. Parameters

* **Gamma (`InpGamma`):** The Laguerre filter coefficient, a value between 0.0 and 1.0. This parameter controls the indicator's speed and smoothness.
  * **High Gamma (e.g., 0.7 - 0.9):** Results in a **slower, smoother** oscillator that gives fewer, but potentially more reliable, signals.
  * **Low Gamma (e.g., 0.1 - 0.3):** Results in a **faster, more volatile** oscillator that reacts quickly to price changes but may produce more false signals.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.
* **Signal Line Settings:**
  * **`InpDisplayMode`:** Toggles the visibility of the signal line (`DISPLAY_LRSI_ONLY` or `DISPLAY_LRSI_AND_SIGNAL`).
  * **`InpSignalPeriod`:** The lookback period for the signal line's moving average.
  * **`InpSignalMAType`:** The type of moving average for the signal line (SMA, EMA, etc.).

## 5. Usage and Interpretation

The Laguerre RSI's primary advantage is its clarity. The addition of a signal line provides an extra dimension for signal generation.

### **1. Overbought / Oversold Reversals**

This is the most common use. Due to its "sharp" turning behavior, levels like 80/20 or even 90/10 are often more effective than the traditional 70/30.

* **Buy Signal:** The indicator line crosses up from below the oversold level (e.g., 20). This suggests bearish momentum is exhausted.
* **Sell Signal:** The indicator line crosses down from above the overbought level (e.g., 80). This suggests bullish momentum is exhausted.
* **Best Use:** This strategy works best in **ranging or consolidating markets**.

### **2. Centerline Crossover (Trend Following)**

The 50-level acts as a balance point between bullish and bearish momentum.

* **Bullish Filter:** When the Laguerre RSI is **above 50**, the momentum is considered bullish. Traders may look for long entries and avoid short positions.
* **Bearish Filter:** When the Laguerre RSI is **below 50**, the momentum is considered bearish.

### **3. Divergence (Advanced Reversal Signal)**

Divergence is one of the most powerful signals, and it is often very clear on the smooth Laguerre RSI line.

* **Bullish Divergence:** Price makes a **new lower low**, but the Laguerre RSI makes a **higher low**. This indicates weakening sell pressure and a potential bottom.
* **Bearish Divergence:** Price makes a **new higher high**, but the Laguerre RSI makes a **lower high**. This indicates weakening buy pressure and a potential top.

### **4. Exit Strategies (Example for a Long Position)**

* **Conservative (Quick Profit):** Exit when the indicator crosses into the overbought zone (e.g., above 80).
* **Balanced (Trend Following):** Hold the position as long as the indicator stays above the 50 centerline. Exit when it crosses below 50.
* **Advanced (Peak Exit):** Hold the position until a clear bearish divergence forms.

### **5. Signal Line Crossover (Momentum Signal)**

The interaction between the Laguerre RSI line and its signal line provides faster, MACD-style momentum signals.

* **Bullish Crossover:** When the **Laguerre RSI line (blue) crosses above the Signal Line (red)**, it indicates a short-term shift to bullish momentum. This can be used as an entry trigger, especially if it occurs in the oversold zone or after a bullish divergence.
* **Bearish Crossover:** When the **Laguerre RSI line crosses below the Signal Line**, it indicates a shift to bearish momentum and can be used as a sell or exit signal.
