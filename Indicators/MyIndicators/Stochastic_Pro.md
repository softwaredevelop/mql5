# Stochastic Pro Oscillator

## 1. Summary (Introduction)

The Stochastic Pro is an enhanced and highly flexible version of the classic Stochastic Oscillator. While the standard "Slow Stochastic" uses a fixed Simple Moving Average (SMA) for its smoothing steps, this "Pro" version allows the trader to select from four different moving average types for both the initial smoothing ("Slowing") and the final signal line ("%D").

This customization allows for fine-tuning the oscillator's responsiveness and smoothness to a degree not possible with the standard indicator. It can be configured to behave as a **classic Slow Stochastic**, replicate the **MetaTrader-specific Smoothed Stochastic**, or create entirely new, hybrid versions.

## 2. Mathematical Foundations and Calculation Logic

The Stochastic Pro follows the structure of the Slow Stochastic but generalizes the moving average calculations.

### Required Components

- **%K Period:** The lookback period for the initial Stochastic calculation.
- **Slowing Period & MA Type:** The period and MA type for the first smoothing step.
- **%D Period & MA Type:** The period and MA type for the second smoothing step (the signal line).

### Calculation Steps (Algorithm)

1. **Calculate the Raw %K (Fast %K):** This is the core Stochastic calculation.
   $\text{Raw \%K}_i = 100 \times \frac{\text{Close}_i - \text{Lowest Low}_{\%K \text{ Period}}}{\text{Highest High}_{\%K \text{ Period}} - \text{Lowest Low}_{\%K \text{ Period}}}$

2. **Calculate the %K Line (Slowing):** The Raw %K line is smoothed using the selected `Slowing Period` and `Slowing MA Type`.
   $\text{\%K}_i = \text{MA}(\text{Raw \%K}, \text{Slowing Period}, \text{Slowing MA Type})_i$

3. **Calculate the %D Line (Signal):** The signal line is a moving average of the %K line, using the selected `%D Period` and `%D MA Type`.
   $\text{\%D}_i = \text{MA}(\text{\%K}, \text{\%D Period}, \text{\%D MA Type})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a self-contained, robust, and highly flexible indicator built upon our established coding principles.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Fully Manual MA Calculations:** To guarantee 100% accuracy and consistency across all MA types within our `non-timeseries` model, all four moving average calculations (**SMA, EMA, SMMA, LWMA**) are performed **manually**. The indicator is completely independent of the `<MovingAverages.mqh>` standard library.

  - **Robust Initialization:** All recursive MA types (EMA, SMMA) are carefully initialized with a manual Simple Moving Average (SMA).

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop, making the logic easy to follow.

- **Heikin Ashi Variant:** A "pure" Heikin Ashi version can be easily created by modifying this code to use Heikin Ashi price data as its input, providing a doubly-smoothed oscillator.

## 4. Parameters

- **%K Period (`InpKPeriod`):** The lookback period for the initial Stochastic calculation. Default is `5`.
- **Slowing Period (`InpSlowingPeriod`):** The period for the first smoothing step. Default is `3`.
- **Slowing MA Type (`InpSlowingMAType`):** The MA type for the first smoothing step. **Default is `MODE_SMA`**.
- **%D Period (`InpDPeriod`):** The period for the signal line smoothing. Default is `3`.
- **%D MA Type (`InpDMAType`):** The MA type for the signal line. **Default is `MODE_SMMA`**.

### Configuration Examples

- **Classic Slow Stochastic:**
  - `Slowing MA Type`: `MODE_SMA`
  - `%D MA Type`: `MODE_SMA`
- **MetaTrader Default Stochastic:**
  - `Slowing MA Type`: `MODE_SMA`
  - `%D MA Type`: `MODE_SMMA`
- **Fast Stochastic:**
  - `Slowing Period`: `1`
  - `Slowing MA Type`: `MODE_SMA`
  - `%D MA Type`: `MODE_SMA`

## 5. Usage and Interpretation

The interpretation of the Stochastic Pro is identical to the standard Stochastic, but the signals may be faster or slower depending on the selected MA types.

- **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
- **Crossovers:** The crossover of the %K line and the %D signal line is a common trade signal. A bullish crossover in oversold territory is a strong signal, and a bearish crossover in overbought territory is a strong signal.
- **Divergence:** Divergences between the oscillator and the price can signal weakening momentum and potential reversals.
- **Caution:** The Stochastic is a range-bound oscillator and performs best in sideways or choppy markets. In a strong trend, it can remain in overbought or oversold territory for extended periods.
