# Ergodic Directional Trend Index (DTI)

## 1. Summary (Introduction)

The Ergodic Directional Trend Index (DTI) is a sophisticated trend oscillator developed by William Blau. It is designed to measure the direction and strength of a trend in a manner similar to Wilder's ADX, but it utilizes Blau's signature "Ergodic" double-smoothing methodology to produce a much smoother and less noisy output.

The indicator is based on the momentum of high and low prices. By double-smoothing this directional momentum, the DTI provides a clear, responsive, and reliable oscillator that fluctuates around a zero line, helping traders to identify the prevailing trend and its strength.

The **Ergodic DTI Oscillator** is a supplementary indicator that displays the difference between the main DTI line and its signal line as a histogram, providing a clearer visual of accelerating and decelerating trend momentum.

## 2. Mathematical Foundations and Calculation Logic

The Ergodic DTI calculation applies the double-smoothing logic of the True Strength Index (TSI) to a unique directional momentum input.

### Required Components

- **Momentum Period (N_mom):** The lookback period for calculating directional momentum.
- **Slow EMA Period (N_slow):** The period for the first, longer-term EMA smoothing.
- **Fast EMA Period (N_fast):** The period for the second, shorter-term EMA smoothing.
- **Signal Period:** The period for the optional moving average signal line.
- **Price Data:** The `High` and `Low` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Directional Momentum:** For each bar, calculate the upward and downward momentum based on the change in Highs and Lows over the `N_mom` period.

   - $\text{Up Momentum}_i = \text{Max}(0, \text{High}_i - \text{High}_{i - N_{\text{mom}}})$
   - $\text{Down Momentum}_i = \text{Max}(0, \text{Low}_{i - N_{\text{mom}}} - \text{Low}_i)$

2. **Calculate Composite High/Low Momentum (HLM):** Subtract the Down Momentum from the Up Momentum.
   $\text{HLM}_i = \text{Up Momentum}_i - \text{Down Momentum}_i$

3. **First EMA Smoothing (Slow Period):** Apply an `N_slow`-period EMA to both the `HLM` and its absolute value.
   $\text{EMA}_{\text{slow}}(\text{HLM})_i = \text{EMA}(\text{HLM}, N_{\text{slow}})_i$
   $\text{EMA}_{\text{slow}}(\text{AbsHLM})_i = \text{EMA}(\text{Abs}(\text{HLM}), N_{\text{slow}})_i$

4. **Second EMA Smoothing (Fast Period):** Apply an `N_fast`-period EMA to the results of the first smoothing step.
   $\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{HLM}))_i = \text{EMA}(\text{EMA}_{\text{slow}}(\text{HLM}), N_{\text{fast}})_i$
   $\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{AbsHLM}))_i = \text{EMA}(\text{EMA}_{\text{slow}}(\text{AbsHLM}), N_{\text{fast}})_i$

5. **Calculate the Ergodic DTI Value:** Divide the double-smoothed HLM by the double-smoothed absolute HLM and scale the result to 100.
   $\text{DTI}_i = 100 \times \frac{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{HLM}))_i}{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{AbsHLM}))_i}$

6. **Calculate the Signal Line & Oscillator:** The signal line is a moving average of the DTI line, and the oscillator is the difference between the two.

## 3. MQL5 Implementation Details

Our MQL5 implementations are self-contained, robust, and accurate representations of the Ergodic DTI and its oscillator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Fully Manual EMA Calculations:** All EMA calculations are performed **manually**. Each recursive EMA calculation is carefully initialized with a **manual Simple Moving Average (SMA)** to provide a stable starting point for the calculation chain and to prevent floating-point overflows.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop, making the complex, multi-stage logic easy to follow.

- **Flexible Signal Line:** The `Blau_Ergodic_DTI.mq5` indicator includes a user-configurable moving average signal line, with a robust `switch` block that correctly handles all MA types (SMA, EMA, SMMA, LWMA).

- **Heikin Ashi Variant (`Blau_Ergodic_DTI_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high` and `ha_low` values to calculate the initial directional momentum.
  - This results in an exceptionally smooth trend oscillator, ideal for filtering out market noise.

## 4. Parameters

- **Momentum Period (`InpMomentumPeriod`):** The lookback period for the initial High/Low momentum calculation. Default is `1`.
- **Slow Period (`InpSlowPeriod`):** The period for the first, longer-term EMA smoothing. Default is `20`.
- **Fast Period (`InpFastPeriod`):** The period for the second, shorter-term EMA smoothing. Default is `5`.
- **Signal Line Settings:**
  - `InpSignalPeriod`: The lookback period for the signal line. Default is `3`.
  - `InpSignalMAType`: The type of moving average for the signal line. Default is `MODE_EMA`.

## 5. Usage and Interpretation

The Ergodic DTI is a powerful trend-following oscillator.

- **Zero Line Crossovers:** This is a primary trend signal.
  - **Bullish:** A crossover of the DTI line above the zero line indicates that upward directional momentum is now dominant.
  - **Bearish:** A crossover below the zero line indicates that downward directional momentum is dominant.
- **Signal Line Crossovers:** Provide earlier, shorter-term signals about shifts in trend momentum.
- **Overbought/Oversold Levels:** The +25 and -25 levels can be used to identify periods of strong, potentially overextended trend momentum.
- **Divergence:** Divergences between price and the DTI can be powerful signals of a weakening trend. For example, if the price makes a new high but the DTI fails to do so, it suggests the underlying upward momentum is fading.
- **Oscillator (Histogram):** The `Blau_Ergodic_DTI_Oscillator` provides a clear visual of the relationship between the DTI and its signal line, highlighting the acceleration and deceleration of the trend's momentum.
