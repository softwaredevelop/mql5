# DSMA Professional (Deviation Scaled Moving Average)

## 1. Summary (Introduction)

The DSMA (Deviation Scaled Moving Average), developed by John Ehlers, is a sophisticated adaptive moving average that adjusts its speed based on a normalized measure of market volatility.

Unlike other adaptive moving averages that rely on momentum or cycle periods, the DSMA modifies its smoothing factor (`alpha`) based on the amplitude of an internal oscillator scaled by its own standard deviation. This unique approach results in a filter with a highly desirable behavior:

* In **high-volatility, trending markets**, the DSMA becomes **fast and responsive**, closely tracking price action to reduce lag.
* In **low-volatility, consolidating markets**, the DSMA becomes **slow and smooth**, flattening out to effectively filter market noise and prevent whipsaw trades.

The DSMA serves as an intelligent, all-in-one trendline that provides visual cues about both the direction of the trend and the current state of market volatility.

## 2. Mathematical Foundations and Calculation Logic

The DSMA is an Exponential Moving Average where the `alpha` is dynamically calculated through a multi-stage filtering process.

### Required Components

* **Period (N):** The primary lookback period for the calculation.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **"Zeros" Oscillator:** A simple, zero-mean oscillator is created by taking the difference between the current price and the price from two bars ago: `Zeros = P[0] - P[2]`. This helps to "whiten" the price spectrum.
2. **Initial Smoothing (SuperSmoother):** The noisy "Zeros" oscillator is smoothed using a **SuperSmoother filter**. The period of this internal SuperSmoother is set to `N/2`.
3. **Standard Deviation (RMS) Calculation:** The algorithm calculates the Root Mean Square (RMS), which is a form of standard deviation, of the smoothed oscillator's output over the last `N` bars.
4. **Scaling:** The current value of the smoothed oscillator is divided by its RMS. This scales the oscillator's amplitude in terms of standard deviations, creating a normalized volatility measure.
5. **Adaptive Alpha Calculation:** The final adaptive `alpha` is calculated as being directly proportional to the absolute value of the scaled oscillator:
    $\alpha = \text{Abs}(\text{Scaled Oscillator}) \times \frac{5}{N}$
6. **Final EMA Calculation:** The DSMA is calculated using the standard EMA formula with the adaptive `alpha`:
    $\text{DSMA}_i = \alpha \times P_i + (1 - \alpha) \times \text{DSMA}_{i-1}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Self-Contained Calculator (`DSMA_Calculator.mqh`):** The entire complex, multi-stage calculation is encapsulated within a dedicated, reusable calculator class.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** The internal buffers (for the Zeros oscillator, the SuperSmoother output, and the final DSMA) persist their state between ticks. This allows the recursive filters to continue seamlessly from the last known values without re-processing the entire history.

* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.

## 4. Parameters

* **Period (`InpPeriod`):** The "critical period" of the filter. This single parameter controls both the lookback window for the RMS calculation and the period of the internal SuperSmoother filter (which will be `Period/2`). Ehlers' recommendation for daily charts is **40**.
  * A longer period results in a smoother, slower-adapting filter.
  * A shorter period results in a faster, more responsive filter.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The DSMA should be used as an "intelligent" moving average that provides clear visual information about the market's current regime (trending vs. ranging).

### **1. Adaptive Trend Following & Dynamic S/R**

This is the primary use case. The DSMA acts as a single, adaptive trendline.

* **In a Trending Market:** The DSMA will be angled steeply and follow the price closely. In this state, it acts as a reliable **dynamic support level** (in an uptrend) or **resistance level** (in a downtrend). Pullbacks to the DSMA line offer high-probability, trend-following entry opportunities.
* **In a Ranging Market:** The DSMA will flatten out and move slowly. This is a clear visual signal that the market is consolidating and trend-following strategies should be avoided. The flat line acts as a "mean" or center of gravity for the price action.

### **2. Volatility Breakout Confirmation**

The change in the DSMA's behavior is a signal in itself.

* **The Setup:** Identify periods where the DSMA has been flat and slow for an extended time, indicating a period of low volatility ("coiling").
* **The Signal:** When the price breaks out of this consolidation, watch for the DSMA to "wake up." A sharp change in its angle, as it begins to accelerate and track the price, serves as a strong **confirmation** that the breakout is valid and a new trend may be starting.
