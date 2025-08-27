# Ergodic MACD

## 1. Summary (Introduction)

The Ergodic MACD is an advanced oscillator based on the concepts of William Blau. It takes the classic Moving Average Convergence/Divergence (MACD) indicator and applies an additional layer of Blau's signature "Ergodic" double-smoothing to its components.

The result is an "ultra-smooth" version of the MACD. Its primary purpose is to filter out the noise and frequent whipsaws present in the standard MACD, providing clearer, though slightly more delayed, signals about the underlying momentum trend. It is designed for traders who prefer smoother, less erratic oscillators.

The **Ergodic MACD Oscillator** is a supplementary indicator that displays the difference between the main Ergodic MACD line and its Ergodic Signal line as a histogram.

## 2. Mathematical Foundations and Calculation Logic

The Ergodic MACD is a multi-stage indicator that builds upon the classic MACD by adding two further layers of exponential smoothing.

### Required Components

- **Classic MACD Parameters:** Fast EMA Period (N_fast), Slow EMA Period (N_slow), Signal EMA Period (N_signal).
- **Ergodic Smoothing Parameters:** A Slow Smoothing Period (N_slow_smooth) and a Fast Smoothing Period (N_fast_smooth).
- **Final Signal Line Parameters:** A period and MA type for the final signal line.

### Calculation Steps (Algorithm)

1. **Calculate the Classic MACD:** First, the standard MACD Line and Signal Line are calculated.

   - $\text{MACD Line}_i = \text{EMA}(\text{Price}, N_{\text{fast}}) - \text{EMA}(\text{Price}, N_{\text{slow}})$
   - $\text{Signal Line}_i = \text{EMA}(\text{MACD Line}, N_{\text{signal}})$

2. **Apply First Ergodic Smoothing (Slow Period):** Apply an `N_slow_smooth`-period EMA to both the classic MACD Line and the classic Signal Line.

   - $\text{EMA1}_{\text{MACD}} = \text{EMA}(\text{MACD Line}, N_{\text{slow\_smooth}})$
   - $\text{EMA1}_{\text{Signal}} = \text{EMA}(\text{Signal Line}, N_{\text{slow\_smooth}})$

3. **Apply Second Ergodic Smoothing (Fast Period):** Apply an `N_fast_smooth`-period EMA to the results of the first smoothing step. This completes the double-smoothing process.

   - $\text{Ergodic MACD}_i = \text{EMA}(\text{EMA1}_{\text{MACD}}, N_{\text{fast\_smooth}})$
   - $\text{Ergodic Signal}_i = \text{EMA}(\text{EMA1}_{\text{Signal}}, N_{\text{fast\_smooth}})$

4. **Calculate the Final Signal Line (Optional):** In our implementation, the `Ergodic Signal` serves as the final signal line. However, one could add yet another moving average on top of the `Ergodic MACD` line. _(Our implementation simplifies this by directly smoothing both lines.)_

5. **Calculate the Ergodic MACD Oscillator:** The oscillator is the difference between the two final, double-smoothed lines.
   $\text{Oscillator}_i = \text{Ergodic MACD}_i - \text{Ergodic Signal}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementations are self-contained, robust, and accurate representations of this advanced oscillator concept.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Fully Manual EMA Calculations:** All of the numerous EMA calculations are performed **manually**. Each recursive EMA calculation is carefully initialized with a **manual Simple Moving Average (SMA)** to provide a stable starting point for the calculation chain and to prevent floating-point overflows.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps. It first calculates the complete classic MACD (line and signal) in an internal buffer. It then applies the two layers of Ergodic smoothing to these internal buffers before writing the final values to the plot buffers. This makes the complex, multi-stage logic easy to follow.

- **Separated Indicators:** Following our toolkit's design philosophy, the functionality is split into two indicators:

  - **`Blau_Ergodic_MACD.mq5`:** Plots the final `Ergodic MACD` and `Ergodic Signal` lines.
  - **`Blau_Ergodic_MACD_Oscillator.mq5`:** Plots the difference between the two lines as a histogram.

- **Heikin Ashi Variants:**
  - Both indicators have "pure" Heikin Ashi counterparts. The calculation logic is identical, but the initial, underlying classic MACD is calculated from the smoothed Heikin Ashi price data. This results in a "triply-smoothed" oscillator, offering maximum noise reduction.

## 4. Parameters

- **Classic MACD Settings:** `InpFastEMAPeriod` (12), `InpSlowEMAPeriod` (26), `InpSignalEMAPeriod` (9).
- **Ergodic Smoothing Settings:**
  - `InpSlowSmoothPeriod`: The period for the first, longer-term smoothing layer. Default is `20`.
  - `InpFastSmoothPeriod`: The period for the second, shorter-term smoothing layer. Default is `5`.
- **Final Signal Line Settings (for the line version):**
  - `InpFinalSignalPeriod`: The lookback period for the final signal line.
  - `InpFinalSignalMAType`: The type of moving average for the final signal line.

## 5. Usage and Interpretation

The Ergodic MACD is interpreted similarly to a standard MACD, but its signals are significantly smoother and therefore more delayed. It is best suited for longer-term trend analysis.

- **Crossovers:** Crossovers between the Ergodic MACD and its Ergodic Signal line are the primary signals. Due to the heavy smoothing, these signals are less frequent but potentially more reliable than classic MACD crossovers.
- **Zero Line Crossovers:** A cross of the Ergodic MACD line above/below zero indicates a significant, long-term shift in momentum.
- **Divergence:** Divergences are still valid but will form over much longer periods than with a standard MACD.
- **Oscillator (Histogram):** The histogram shows the convergence and divergence of the two smoothed lines, providing a visual representation of the acceleration and deceleration of the underlying, smoothed momentum.
