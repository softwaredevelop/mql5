# Slow Stochastic Professional

## 1. Summary (Introduction)

The Stochastic Oscillator, developed by George C. Lane, is a momentum indicator that compares a closing price to its price range over a period. The "Slow" version is the most commonly used variant, as it includes an internal smoothing mechanism that filters out noise.

Our **Stochastic Slow Pro** is a highly flexible and professional implementation that elevates the classic indicator into a fully customizable tool. It allows the user to select the **Moving Average type** for both smoothing steps (%K Slowing and %D Signal Line) independently. Furthermore, it features a seamless, built-in option to calculate the oscillator based on either **standard price data or smoothed Heikin Ashi data**.

This provides traders with a powerful tool to replicate classic definitions, match platform-specific behaviors (like MetaTrader's default SMMA for the %D line), or create entirely new, custom-smoothed Stochastic oscillators.

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
    The entire calculation logic for both standard and Heikin Ashi versions, including the flexible MA smoothing, is encapsulated within a single, powerful include file.
  * An elegant, object-oriented inheritance model (`CStochasticSlowCalculator` and `CStochasticSlowCalculator_HA`) allows the main indicator file to dynamically choose the correct calculation engine at runtime based on user input, eliminating code duplication.

* **Full MA Type Support:** The calculator contains a complete, robust implementation for all standard MQL5 MA types (SMA, EMA, SMMA, LWMA) for both the "Slowing" and the "%D" smoothing steps.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` to ensure that the multi-stage calculation remains stable and accurate.

## 4. Parameters

* **%K Period (`InpKPeriod`):** The lookback period for the initial Stochastic calculation. Default is `5`.
* **Slowing Period (`InpSlowingPeriod`):** The smoothing period for the main Slow %K line. Default is `3`.
* **Slowing MA Type (`InpSlowingMAType`):** The MA type for the "Slowing" step. Default is `MODE_SMA`.
* **%D Period (`InpDPeriod`):** The smoothing period for the final signal line (%D). Default is `3`.
* **%D MA Type (`InpDMAType`):** The MA type for the "%D" step. Default is `MODE_SMA`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).

### Configuration Examples

* **Classic Slow Stochastic:**
  * `Slowing MA Type`: `MODE_SMA`
  * `%D MA Type`: `MODE_SMA`
* **MetaTrader Default Stochastic:**
  * `Slowing MA Type`: `MODE_SMA`
  * `%D MA Type`: `MODE_SMMA`
* **Fast Stochastic:**
  * `Slowing Period`: `1`
  * `Slowing MA Type`: `MODE_SMA`

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
* **Crossovers:** The crossover of the %K line and the %D signal line is a common trade signal.
* **Divergence:** Look for divergences between the Stochastic and the price action.
* **Using Heikin Ashi:** Selecting the Heikin Ashi option results in a significantly smoother oscillator, which can be useful for filtering out market noise.
* **Caution:** The Stochastic is a range-bound oscillator and performs best in sideways markets. In a strong trend, it can remain in overbought or oversold territory for extended periods.
