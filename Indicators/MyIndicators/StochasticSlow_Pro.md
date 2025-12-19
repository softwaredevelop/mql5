# Slow Stochastic Pro

## 1. Summary (Introduction)

The Stochastic Oscillator, developed by George C. Lane, is a momentum indicator that compares a closing price to its price range over a period. The "Slow" version is the most commonly used variant, as it includes an internal smoothing mechanism that filters out noise.

Our **Stochastic Slow Pro** is a highly flexible and professional implementation that elevates the classic indicator into a fully customizable tool. It allows the user to select the **Moving Average type** for both smoothing steps (%K Slowing and %D Signal Line) independently. Furthermore, it features a seamless, built-in option to calculate the oscillator based on either **standard price data or smoothed Heikin Ashi data**.

This provides traders with a powerful tool to replicate classic definitions, match platform-specific behaviors (like MetaTrader's default SMMA for the %D line), or create entirely new, custom-smoothed Stochastic oscillators (e.g., using DEMA for faster reaction).

## 2. Mathematical Foundations and Calculation Logic

The Slow Stochastic is derived from the Fast Stochastic by adding two layers of smoothing.

### Required Components

* **%K Period:** The main lookback period for the Stochastic calculation.
* **Slowing Period & MA Method:** The period and type of moving average for the first smoothing step.
* **%D Period & MA Method:** The period and type of moving average for the second smoothing step (the signal line).
* **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate the Raw %K (Fast %K):** This is the core of the Stochastic calculation.
    $\text{Raw \%K}_t = 100 \times \frac{\text{Close}_t - \text{Lowest Low}_{\%K \text{ Period}}}{\text{Highest High}_{\%K \text{ Period}} - \text{Lowest Low}_{\%K \text{ Period}}}$

2. **Calculate the Slow %K (Main Line):** The Raw %K line is smoothed using the selected `Slowing MA Method` and `Slowing Period`.
    $\text{Slow \%K}_t = \text{MA}(\text{Raw \%K}, \text{Slowing Period}, \text{Slowing MA Method})_t$

3. **Calculate the %D (Signal Line):** The signal line is a moving average of the Slow %K line, using the selected `%D MA Method` and `%D Period`.
    $\text{Slow \%D}_t = \text{MA}(\text{Slow \%K}, \text{\%D Period}, \text{\%D MA Method})_t$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a robust, unified indicator built on a modular, object-oriented framework.

* **Modular Calculation Engine (`StochasticSlow_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **Composition Pattern:** The calculator internally uses **two instances** of our powerful `MovingAverage_Engine`. One handles the "Slowing" step, and the other handles the "%D" signal line. This ensures mathematical consistency and allows for advanced smoothing combinations.

* **Advanced Smoothing Options:**
    Thanks to the integration with the `MovingAverage_Engine`, both smoothing steps support **seven** different methods (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA). This allows for highly specialized configurations, such as a double-smoothed TEMA Stochastic.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks, ensuring seamless updates.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations (Raw %K -> Slow %K -> %D), ensuring that each step starts only when valid data is available. This prevents artifacts and "INF" errors at the beginning of the chart.

* **Object-Oriented Design:**
  * An elegant inheritance model (`CStochasticSlowCalculator` and `CStochasticSlowCalculator_HA`) allows the main indicator file to dynamically choose the correct calculation engine (Standard or Heikin Ashi) at runtime.

## 4. Parameters

* **%K Period (`InpKPeriod`):** The lookback period for the initial Stochastic calculation. (Default: `5`).
* **Slowing Period (`InpSlowingPeriod`):** The smoothing period for the main Slow %K line. (Default: `3`).
* **Slowing MA Type (`InpSlowingMAType`):** The MA type for the "Slowing" step. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).
* **%D Period (`InpDPeriod`):** The smoothing period for the final signal line (%D). (Default: `3`).
* **%D MA Type (`InpDMAType`):** The MA type for the "%D" step. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).

### Configuration Examples

* **Classic Slow Stochastic:**
  * `Slowing MA Type`: `SMA`
  * `%D MA Type`: `SMA`
* **MetaTrader Default Stochastic:**
  * `Slowing MA Type`: `SMA`
  * `%D MA Type`: `SMMA`
* **Ultra-Smooth Stochastic:**
  * `Slowing MA Type`: `TMA`
  * `%D MA Type`: `TMA`

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
* **Crossovers:** The crossover of the %K line and the %D signal line is a common trade signal.
* **Divergence:** Look for divergences between the Stochastic and the price action.
* **Using Heikin Ashi:** Selecting the Heikin Ashi option results in a significantly smoother oscillator, which can be useful for filtering out market noise.
