# Ergodic Stochastic Momentum Index (SMI)

## 1. Summary (Introduction)

The Ergodic SMI is an oscillator developed by William Blau, based on his "Ergodic" methodology. It applies the double-smoothing technique of the True Strength Index (TSI) to the **Stochastic Momentum**, rather than the simple price momentum.

The result is a powerful oscillator that combines the strengths of two different concepts:

1. **Stochastic Momentum:** Measures the current price's position relative to its recent high-low range, providing insight into overbought/oversold conditions.
2. **Ergodic Double Smoothing:** Filters out significant market noise from the raw Stochastic Momentum, resulting in a much smoother and often more reliable oscillator than the standard Stochastic.

The **Ergodic SMI Oscillator** is a supplementary indicator that displays the difference between the main SMI line and its signal line as a histogram, providing a clearer visual of accelerating and decelerating momentum.

## 2. Mathematical Foundations and Calculation Logic

The Ergodic SMI calculation is a multi-stage process that first calculates the Stochastic Momentum and then applies the double EMA smoothing of the TSI.

### Required Components

- **Stochastic Period (N_stoch):** The lookback period for finding the highest high and lowest low.
- **Slow EMA Period (N_slow):** The period for the first, longer-term EMA smoothing.
- **Fast EMA Period (N_fast):** The period for the second, shorter-term EMA smoothing.
- **Signal Period:** The period for the optional moving average signal line.
- **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Stochastic Momentum (SM) and Range:** For each bar, calculate:

   - $\text{Highest High}_N = \text{Max}(\text{High}, N_{\text{stoch}})_i$
   - $\text{Lowest Low}_N = \text{Min}(\text{Low}, N_{\text{stoch}})_i$
   - $\text{Stochastic Momentum (SM)}_i = \text{Close}_i - \frac{\text{Highest High}_N + \text{Lowest Low}_N}{2}$
   - $\text{Range}_i = \text{Highest High}_N - \text{Lowest Low}_N$

2. **First EMA Smoothing (Slow Period):** Apply an `N_slow`-period EMA to both the `SM` and the `Range`.
   $\text{EMA}_{\text{slow}}(\text{SM})_i = \text{EMA}(\text{SM}, N_{\text{slow}})_i$
   $\text{EMA}_{\text{slow}}(\text{Range})_i = \text{EMA}(\text{Range}, N_{\text{slow}})_i$

3. **Second EMA Smoothing (Fast Period):** Apply an `N_fast`-period EMA to the results of the first smoothing step.
   $\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{SM}))_i = \text{EMA}(\text{EMA}_{\text{slow}}(\text{SM}), N_{\text{fast}})_i$
   $\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{Range}))_i = \text{EMA}(\text{EMA}_{\text{slow}}(\text{Range}), N_{\text{fast}})_i$

4. **Calculate the Ergodic SMI Value:** Divide the double-smoothed SM by half of the double-smoothed Range and scale to 100.
   $\text{SMI}_i = 100 \times \frac{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{SM}))_i}{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{Range}))_i / 2}$

5. **Calculate the Signal Line:** The signal line is a moving average of the SMI line itself.
   $\text{Signal}_i = \text{MA}(\text{SMI}, \text{Signal Period})_i$

6. **Calculate the SMI Oscillator:** The oscillator is the difference between the SMI line and its Signal Line.
   $\text{Oscillator}_i = \text{SMI}_i - \text{Signal}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementations are self-contained, robust, and accurate representations of the Ergodic SMI and its oscillator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Fully Manual EMA Calculations:** All EMA calculations are performed **manually**. Each recursive EMA calculation is carefully initialized with a **manual Simple Moving Average (SMA)** to provide a stable starting point for the calculation chain and to prevent floating-point overflows.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop, making the complex, multi-stage logic easy to follow.

- **Flexible Signal Line:** The `Blau_Ergodic_SMI.mq5` indicator includes a user-configurable moving average signal line, with a robust `switch` block that correctly handles all MA types (SMA, EMA, SMMA, LWMA).

- **Heikin Ashi Variant (`Blau_Ergodic_SMI_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` values as its input for the initial Stochastic Momentum calculation.
  - This results in an exceptionally smooth oscillator, ideal for filtering out market noise.

## 4. Parameters

- **Stoch Period (`InpStochPeriod`):** The lookback period for the initial Stochastic calculation. Default is `5`.
- **Slow Period (`InpSlowPeriod`):** The period for the first, longer-term EMA smoothing. Default is `20`.
- **Fast Period (`InpFastPeriod`):** The period for the second, shorter-term EMA smoothing. Default is `5`.
- **Signal Line Settings:**
  - `InpSignalPeriod`: The lookback period for the signal line. Default is `5`.
  - `InpSignalMAType`: The type of moving average for the signal line. Default is `MODE_EMA`.

## 5. Usage and Interpretation

The Ergodic SMI is interpreted similarly to other momentum oscillators like the TSI or MACD, but its signals are often smoother and less frequent.

- **Zero Line Crossovers:** A primary trend signal. A cross above zero indicates bullish momentum is taking control; a cross below indicates bearish momentum.
- **Signal Line Crossovers:** Provide earlier, shorter-term momentum signals for potential entries or exits.
- **Overbought/Oversold Levels:** The **+40 and -40** levels are often used to identify extreme conditions.
- **Divergence:** Due to its smoothness, the Ergodic SMI is excellent for spotting divergences between price and momentum, which can foreshadow reversals.
- **Oscillator (Histogram):** The `Blau_Ergodic_SMI_Oscillator` provides a clear visual of the relationship between the SMI and its signal line, highlighting the acceleration and deceleration of momentum.
