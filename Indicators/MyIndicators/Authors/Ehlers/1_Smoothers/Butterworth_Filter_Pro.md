# Butterworth Filter Professional

## 1. Summary (Introduction)

The Butterworth Filter, introduced to the trading world by John Ehlers, is a type of higher-order, low-pass filter borrowed from the field of digital signal processing. It serves as a superior alternative to traditional moving averages like the SMA or EMA, offering a significantly **smoother output** with a more optimal trade-off between **smoothing and lag**.

Unlike a standard EMA (a "single-pole" filter), a Butterworth filter can be designed with multiple "poles." Each additional pole increases the filter's ability to reject high-frequency market noise, resulting in a much cleaner, less "whippy" trendline.

This indicator allows the user to choose between a **2-pole** and a **3-pole** Butterworth filter, providing a powerful and flexible tool for trend identification and analysis.

## 2. Mathematical Foundations and Calculation Logic

The core concept behind higher-order filters is that more complex recursive equations can create a more desirable filtering effect.

### The Concept of "Poles"

In signal processing, a "pole" can be thought of as a component of the filter's memory.

* A **Simple Moving Average (SMA)** is a FIR filter with no poles; it has no memory of data outside its fixed window.
* An **Exponential Moving Average (EMA)** is a simple IIR filter with **one pole**; its output depends on the previous output value.
* A **Butterworth filter** is an IIR filter with **two or more poles**. Its output depends on several previous output values (`f[1]`, `f[2]`, `f[3]`, etc.), making its memory and smoothing capabilities much more complex and powerful.

The key advantage is that a 2-pole filter attenuates noise at twice the rate (12 dB per octave) of a 1-pole EMA (6 dB per octave), and a 3-pole filter at three times the rate (18 dB per octave). This results in a dramatically smoother line for a given amount of lag.

### Calculation Steps (Algorithm)

The calculation is a recursive process where the current filter value (`f`) is a function of previous filter values and a weighted sum of recent price data. The specific coefficients used in the formula are derived from the user-selected `Period` and the number of `Poles`.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`Butterworth_Calculator.mqh`):** The entire complex, recursive calculation for both the 2-pole and 3-pole filters is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** The calculation is highly state-dependent. To ensure absolute stability and prevent desynchronization errors, the indicator employs a **full recalculation** on every `OnCalculate` call. This is the most robust method for this type of complex IIR filter.

## 4. Parameters

* **Period (`InpPeriod`):** The "critical period" of the filter. This acts similarly to the period of a traditional moving average. A longer period results in a smoother, slower filter, while a shorter period results in a faster, more responsive one. A good starting point is **20**.
* **Poles (`InpPoles`):** The number of poles for the filter, which determines its order and smoothing power.
  * `POLES_TWO`: A 2-pole filter. This is an excellent default, offering a great balance between smoothing and responsiveness.
  * `POLES_THREE`: A 3-pole filter. This provides **maximum smoothing** but also introduces **more lag**. Use this for very noisy markets or for identifying very long-term trends.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The Butterworth Filter should be used as a high-quality, low-noise replacement for traditional moving averages.

### **1. Dynamic Support and Resistance (Primary Use)**

Due to its exceptional smoothness, the filter line acts as a very reliable, dynamic level of support or resistance.

* **Buy Signal:** In an established uptrend, wait for the price to pull back to the Butterworth filter line. A bounce upwards off the line, confirmed by a bullish candle, is a high-probability entry signal.
* **Sell Signal:** In an established downtrend, wait for the price to rally back to the filter line. A rejection downwards from the line is a high-probability short entry signal.

### **2. Trend Filtering**

A longer-period Butterworth filter (e.g., 50 or 100) is an excellent tool for defining the overall market bias.

* **Bullish Bias:** If the price is trading **above** the long-term Butterworth filter, only look for buying opportunities.
* **Bearish Bias:** If the price is trading **below** the long-term Butterworth filter, only look for selling opportunities.

### **3. Two-Line Crossover System**

For more confirmation, two instances of the indicator can be used on the same chart with different periods (e.g., a fast 20-period and a slow 50-period).

* **Buy Signal:** The fast filter crosses above the slow filter.
* **Sell Signal:** The fast filter crosses below the slow filter.

The key advantage of the Butterworth filter over a standard EMA is its ability to ignore minor, insignificant price fluctuations, allowing the trader to focus on the true, underlying trend.

### **Combined Strategy with Butterworth_Calculator (Advanced)**

The filter's characteristics can be better understood when used with its companion oscillator, the `Butterworth_Momentum_Pro`. A key relationship exists between them:

* **The Momentum Oscillator's zero-cross confirms the Filter's turning point.**
  * Because the Butterworth filter is designed for maximum smoothing, it has a significant lag. The `Butterworth_Momentum` oscillator's zero-cross will occur **after** the price has already turned, but it serves as a **very smooth and reliable confirmation** that the trend captured by the `Butterworth_Filter` has indeed changed direction.
  * A cross of the momentum line above zero confirms that the filter has formed a stable **trough (bottom)**.
  * A cross of the momentum line below zero confirms that the filter has formed a stable **peak (top)**.

This combination is useful for strategies that require a high degree of confirmation before entering a trade based on a major trend change.
