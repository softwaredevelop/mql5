# Ergodic Candle Momentum Index (CMI)

## 1. Summary (Introduction)

The Ergodic Candle Momentum Index (CMI) is an oscillator developed by William Blau, based on his "Ergodic" methodology. It is a unique momentum indicator that measures the **strength of the buying or selling pressure within each individual candle**, rather than the momentum between candles.

It achieves this by applying the double-smoothing technique of the True Strength Index (TSI) to the **Candle Momentum** (`Close - Open`), which represents the size and direction of the candle's body. The result is a very smooth oscillator that quantifies the underlying conviction of bulls and bears within each trading period.

The **Ergodic CMI Oscillator** is a supplementary indicator that displays the difference between the main CMI line and its signal line as a histogram.

## 2. Mathematical Foundations and Calculation Logic

The Ergodic CMI calculation is identical in structure to the True Strength Index (TSI), but it uses a different source for its initial momentum calculation.

### Required Components

- **Slow EMA Period (N_slow):** The period for the first, longer-term EMA smoothing.
- **Fast EMA Period (N_fast):** The period for the second, shorter-term EMA smoothing.
- **Signal Period:** The period for the optional moving average signal line.
- **Price Data:** The `Open` and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Candle Momentum (CMtm):** For each bar, calculate the difference between the closing and opening price.
   $\text{CMtm}_i = \text{Close}_i - \text{Open}_i$

2. **First EMA Smoothing (Slow Period):** Apply an `N_slow`-period EMA to both the `CMtm` and its absolute value.
   $\text{EMA}_{\text{slow}}(\text{CMtm})_i = \text{EMA}(\text{CMtm}, N_{\text{slow}})_i$
   $\text{EMA}_{\text{slow}}(\text{AbsCMtm})_i = \text{EMA}(\text{Abs}(\text{CMtm}), N_{\text{slow}})_i$

3. **Second EMA Smoothing (Fast Period):** Apply an `N_fast`-period EMA to the results of the first smoothing step.
   $\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{CMtm}))_i = \text{EMA}(\text{EMA}_{\text{slow}}(\text{CMtm}), N_{\text{fast}})_i$
   $\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{AbsCMtm}))_i = \text{EMA}(\text{EMA}_{\text{slow}}(\text{AbsCMtm}), N_{\text{fast}})_i$

4. **Calculate the Ergodic CMI Value:** Divide the double-smoothed CMtm by the double-smoothed absolute CMtm and scale the result to 100.
   $\text{CMI}_i = 100 \times \frac{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{CMtm}))_i}{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{AbsCMtm}))_i}$

5. **Calculate the Signal Line:** The signal line is a moving average of the CMI line itself.
   $\text{Signal}_i = \text{MA}(\text{CMI}, \text{Signal Period})_i$

6. **Calculate the CMI Oscillator:** The oscillator is the difference between the CMI line and its Signal Line.
   $\text{Oscillator}_i = \text{CMI}_i - \text{Signal}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementations are self-contained, robust, and accurate representations of the Ergodic CMI and its oscillator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Fully Manual EMA Calculations:** All EMA calculations are performed **manually**. Each recursive EMA calculation is carefully initialized with a **manual Simple Moving Average (SMA)** to provide a stable starting point for the calculation chain and to prevent floating-point overflows.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop, making the complex, multi-stage logic easy to follow.

- **Flexible Signal Line:** The `Blau_Ergodic_CMI.mq5` indicator includes a user-configurable moving average signal line, with a robust `switch` block that correctly handles all MA types (SMA, EMA, SMMA, LWMA).

- **Heikin Ashi Variant (`Blau_Ergodic_CMI_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_close` and `ha_open` values to calculate the initial Candle Momentum.
  - This results in an exceptionally smooth oscillator that measures the internal strength of the already-smoothed Heikin Ashi candles.

## 4. Parameters

- **Slow Period (`InpSlowPeriod`):** The period for the first, longer-term EMA smoothing. Default is `20`.
- **Fast Period (`InpFastPeriod`):** The period for the second, shorter-term EMA smoothing. Default is `5`.
- **Signal Line Settings:**
  - `InpSignalPeriod`: The lookback period for the signal line. Default is `3`.
  - `InpSignalMAType`: The type of moving average for the signal line. Default is `MODE_EMA`.

## 5. Usage and Interpretation

The Ergodic CMI is interpreted similarly to other momentum oscillators like the TSI, but its signals are based on intra-bar strength rather than inter-bar trend.

- **Zero Line Crossovers:** A cross above zero indicates that bullish candles (buying pressure) are beginning to dominate over bearish candles (selling pressure) on a smoothed basis. A cross below zero indicates the opposite.
- **Signal Line Crossovers:** Provide earlier, shorter-term signals about shifts in the candle-by-candle momentum.
- **Overbought/Oversold Levels:** The +25 and -25 levels can be used to identify periods of sustained one-sided pressure.
- **Divergence:** Divergences between price and the CMI can be powerful. For example, if the price makes a new high but the CMI fails to do so, it suggests that the recent bullish candles are losing their internal strength and conviction, which can be an early warning of a reversal.
