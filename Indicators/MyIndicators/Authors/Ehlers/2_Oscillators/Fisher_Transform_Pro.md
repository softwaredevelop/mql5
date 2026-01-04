# Fisher Transform Professional

## 1. Summary (Introduction)

The Fisher Transform, developed by John Ehlers, is a powerful technical indicator designed to convert any price or indicator data into a waveform that has a nearly Gaussian (normal) probability distribution. The primary purpose of this transformation is to make market turning points **sharper, clearer, and more timely**.

Unlike traditional oscillators (like MACD or RSI) which often have rounded tops and bottoms, the Fisher Transform creates sharp, V-shaped peaks and troughs. This "amplification" of extreme price movements helps traders identify potential reversals with greater precision and less lag.

The indicator plots two lines:

* **Fisher Line:** The main transformed value.
* **Signal Line:** The Fisher line delayed by one bar, used for generating crossover signals.

Our `Fisher_Transform_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The indicator follows a multi-step process to transform the price data.

### Required Components

* **Period (N):** A lookback period to normalize the price.
* **Alpha (α):** A smoothing factor for the normalized price.
* **Source Price (P):** The price series used for the calculation (Ehlers' original work uses the Median Price `(H+L)/2`).

### Calculation Steps (Algorithm)

1. **Price Normalization:** For each bar, find the highest high and lowest low over the last `N` periods. Use these values to normalize the current price into a range between -1 and +1.
2. **Smoothing:** Apply an EMA-like smoothing to the normalized value from the previous step using the `alpha` factor.
3. **Clamping:** The smoothed value is strictly limited (clamped) to a range just inside -1 and +1 (e.g., -0.999 to +0.999) to prevent mathematical errors in the next step.
4. **Fisher Transform Application:** Apply the core Fisher Transform equation to the clamped value (`x`):
    $y = 0.5 \times \ln\left(\frac{1+x}{1-x}\right)$
5. **Final Smoothing & Signal Line:** The resulting value (`y`) is lightly smoothed, and the Signal Line is generated as the previous bar's Fisher value.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability and performance.

* **Self-Contained Calculator (`Fisher_Transform_Calculator.mqh`):** The entire multi-stage calculation is encapsulated within a dedicated, reusable calculator class.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** The internal buffers (for smoothed values and the final Fisher output) persist their state between ticks. This allows the recursive calculation to continue seamlessly from the last known values without re-processing the entire history.

* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.

* **Definition-True Price Source:** The calculator is hard-coded to use the **Median Price `(High+Low)/2`** as the source, in accordance with John Ehlers' original articles on this specific implementation.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for normalizing the price. Ehlers' recommendation and a good starting point is **10**.
  * A shorter period makes the indicator more sensitive to recent price swings.
  * A longer period makes it smoother and responsive only to larger price movements.
* **Alpha (`InpAlpha`):** The smoothing factor for the normalized price, similar to an EMA's alpha. Ehlers' recommendation is **0.33**. It is generally not recommended to change this value.
* **Source (`InpSource`):** Selects between `Standard` and `Heikin Ashi` candles. The Median Price of the selected candle type will be used.

## 5. Usage and Interpretation

The Fisher Transform is primarily a **timing indicator** for identifying potential reversals.

### **1. Signal Line Crossover (Primary Strategy)**

This is the most direct way to use the indicator.

* **Buy Signal:** The **blue Fisher line crosses above the red Signal line**. This often occurs at or near a market bottom.
* **Sell Signal:** The **blue Fisher line crosses below the red Signal line**. This often occurs at or near a market top.

### **2. Trading Extreme Levels**

The sharp peaks and troughs are the indicator's main feature.

* When the Fisher line reaches an extreme level (e.g., above +1.5 or below -1.5), it signals that a reversal is becoming highly probable.
* A conservative strategy is to wait for the indicator to reach an extreme level and *then* wait for a signal line crossover in the opposite direction as confirmation before entering a trade.

### **Important Consideration: Use with a Trend Filter**

The Fisher Transform is designed to be very responsive and has no trend-following component. In a strong trend, it can generate multiple false signals against the trend. Therefore, it is **highly recommended to use it in conjunction with a trend filter** (e.g., a 100 or 200-period moving average).

* **Uptrend Rule:** Only take **Buy signals** from the Fisher Transform when the price is above the long-term moving average.
* **Downtrend Rule:** Only take **Sell signals** from the Fisher Transform when the price is below the long-term moving average.
