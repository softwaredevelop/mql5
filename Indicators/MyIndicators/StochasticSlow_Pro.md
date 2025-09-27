# Stochastic Pro Oscillator

## 1. Summary (Introduction)

The Stochastic Oscillator, developed by George C. Lane, is a momentum indicator that compares a particular closing price of a security to a range of its prices over a certain period of time. The "Slow" version is the most commonly used variant, as it includes an internal smoothing mechanism that filters out market noise.

Our **Stochastic Pro** is a highly flexible and professional implementation that elevates the classic indicator into a fully customizable tool. It allows the user to select the **Moving Average type** for both smoothing steps (%K Slowing and %D Signal Line) independently. Furthermore, it features a seamless, built-in option to calculate the oscillator based on either **standard price data or smoothed Heikin Ashi data**.

This provides traders with a powerful tool to replicate classic definitions, match platform-specific behaviors (like MetaTrader's default SMMA for the %D line), or create entirely new, custom-smoothed Stochastic oscillators.

## 2. Mathematical Foundations and Calculation Logic

The Slow Stochastic is derived from the Fast Stochastic by adding two layers of smoothing.

### Required Components

- **%K Period:** The main lookback period for the Stochastic calculation.
- **Slowing Period & MA Method:** The period and type of moving average for the first smoothing step (transforming "Fast %K" into "Slow %K").
- **%D Period & MA Method:** The period and type of moving average for the second smoothing step (creating the signal line %D).
- **Price Data:** The `High`, `Low`, and `Close` of each bar (either standard or Heikin Ashi).

### Calculation Steps (Algorithm)

1. **Prepare Price Data:** The indicator first prepares the necessary `High`, `Low`, and `Close` price series. Based on user selection, it either uses the standard chart prices or calculates and uses the smoothed Heikin Ashi prices.

2. **Calculate the Raw %K (Fast %K):** This is the core of the Stochastic calculation. It measures where the current close is relative to the price range over the `%K Period`.
    $\text{Raw \%K}_t = \frac{\text{Close}_t - \text{Lowest Low}_{\%K \text{ Period}}}{\text{Highest High}_{\%K \text{ Period}} - \text{Lowest Low}_{\%K \text{ Period}}} \times 100$

3. **Calculate the Slow %K (Main Line):** The Raw %K line is smoothed using the selected `Slowing MA Method` and `Slowing Period`. This smoothed line becomes the main `%K` line.
    $\text{Slow \%K}_t = \text{MA}(\text{Raw \%K}, \text{Slowing Period}, \text{Slowing MA Method})_t$

4. **Calculate the %D (Signal Line):** The signal line is a moving average of the Slow %K line, using the selected `%D MA Method` and `%D Period`.
    $\text{Slow \%D}_t = \text{MA}(\text{Slow \%K}, \text{\%D Period}, \text{\%D MA Method})_t$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a robust, unified indicator built on a modular, object-oriented framework.

- **Modular, Reusable Calculation Engine (`Stochastic_Calculator.mqh`):** The entire calculation logic for both standard and Heikin Ashi versions, including the flexible MA smoothing, is encapsulated within a single, powerful include file.
  - An elegant, object-oriented inheritance model (`CStochasticCalculator` and `CStochasticCalculator_HA`) allows the main indicator file to dynamically choose the correct calculation engine at runtime based on user input, eliminating code duplication.

- **Full MA Type Support:** The calculator contains a complete, robust implementation for all standard MQL5 MA types (SMA, EMA, SMMA, LWMA) for both the "Slowing" and the "%D" smoothing steps. This includes proper initialization for recursive averages (EMA, SMMA) within our "full recalculation" model.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This ensures that the multi-stage calculation remains stable and accurate, especially during timeframe changes or history loading.

- **Unified "Pro" Indicator:** Instead of separate standard and Heikin Ashi files, we have a single `StochasticSlow_Pro.mq5`. A simple `input bool` allows the user to seamlessly switch between the two price sources, making the indicator cleaner and easier to manage.

## 4. Parameters

- **%K Period (`InpKPeriod`):** The lookback period for the initial Stochastic calculation. Default is `5`.
- **Slowing Period (`InpSlowingPeriod`):** The smoothing period applied to the Raw %K to create the main Slow %K line. Default is `3`.
- **Slowing Method (`InpSlowingMethod`):** The type of moving average used for the "Slowing" step. Default is `MODE_SMA` (classic definition).
- **%D Period (`InpDPeriod`):** The smoothing period for the final signal line (%D). Default is `3`.
- **%D Method (`InpDMethod`):** The type of moving average used for the "%D" step. Default is `MODE_SMA` (classic definition). Set to `MODE_SMMA` to replicate the behavior of the standard MT5 Stochastic.
- **Use Heikin Ashi (`InpUseHeikinAshi`):** If `true`, the indicator performs all calculations on smoothed Heikin Ashi HLC prices. Default is `false`.

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
- **Crossovers:** The crossover of the %K line and the %D signal line is a common trade signal. A crossover of %K above %D is considered bullish; a crossover of %K below %D is considered bearish.
- **Divergence:** Look for divergences between the Stochastic and the price action. A bearish divergence (price makes a new high, Stochastic does not) can signal weakening momentum. A bullish divergence (price makes a new low, Stochastic makes a higher low) can signal a potential bottom.
- **Using Heikin Ashi:** Selecting the Heikin Ashi option results in a significantly smoother oscillator, as the input data itself is already filtered. This can be useful for traders who want to focus on the primary momentum shifts and filter out market noise, potentially leading to fewer but higher-quality signals.
- **Caution:** The Stochastic is a range-bound oscillator and performs best in sideways or choppy markets. In a strong trend, it can remain in overbought or oversold territory for extended periods, giving premature or false reversal signals.
