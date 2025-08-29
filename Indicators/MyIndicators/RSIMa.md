# Moving Average of RSI (RSI with Signal Line)

## 1. Summary (Introduction)

This indicator plots the standard Relative Strength Index (RSI) and overlays a moving average of the RSI, which acts as a **signal line**. While the RSI is a powerful momentum oscillator, it can often be volatile. Applying a moving average filters out short-term noise, providing a smoother line that can make the underlying momentum trend easier to identify.

The **RSI Oscillator** is a supplementary indicator that displays the difference between the main RSI line and its signal line as a histogram. It provides a clearer visual representation of accelerating and decelerating momentum, similar to the MACD histogram.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a two-stage process. It first calculates the standard RSI and then applies a moving average to the resulting RSI values.

### Required Components

- **RSI (Relative Strength Index):** The underlying momentum oscillator.
- **Moving Average (MA):** The smoothing mechanism applied to the RSI line.

### Calculation Steps (Algorithm)

1. **Calculate the RSI:** First, calculate the standard RSI for a given period (e.g., 14) on the source price. The RSI formula is based on Wilder's smoothing of average gains and average losses.
   $\text{RS}_i = \frac{\text{Wilder's MA}(\text{Up Moves}, \text{RSI Period})_i}{\text{Wilder's MA}(\text{Down Moves}, \text{RSI Period})_i}$
   $\text{RSI}_i = 100 - \frac{100}{1 + \text{RS}_i}$

2. **Calculate the Moving Average of RSI (Signal Line):** Apply the selected moving average type with its specified period to the RSI data series calculated in the first step.
   $\text{Signal Line}_i = \text{MA}(\text{RSI}, \text{MA Period})_i$

3. **Calculate the RSI Oscillator:** The oscillator is the difference between the RSI line and its Signal Line.
   $\text{Oscillator}_i = \text{RSI}_i - \text{Signal Line}_i$

## 3. MQL5 Implementation Details

Our MQL5 implementations are designed for stability, clarity, and consistency.

- **Stability via Full Recalculation:** All versions employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Self-Contained Logic:** All versions are completely self-contained. The standard version uses a handle to MQL5's built-in `iRSI` for efficiency, while the Heikin Ashi version uses our custom `CHeikinAshi_RSI_Calculator`.

- **Fully Manual MA Calculations:** To guarantee 100% accuracy and consistency, all moving average calculations for the signal line (**SMA, EMA, SMMA, LWMA**) are performed **manually**. This makes the indicators independent of the `<MovingAverages.mqh>` library and ensures robust behavior on `non-timeseries` arrays.

- **Indicator Family:**

  - **Line Versions:** `RSIMA.mq5` and `RSI_HeikinAshi.mq5` plot the RSI line and its signal line.
  - **Oscillator Versions:** `RSI_Oscillator.mq5` and `RSI_Oscillator_HeikinAshi.mq5` plot the difference between the two lines as a histogram.

- **Heikin Ashi Variant (`RSI_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_close` values as the input for the initial RSI calculation. This results in a doubly-smoothed oscillator.

## 4. Parameters

- **RSI Period (`InpPeriodRSI`):** The lookback period for the underlying RSI calculation. Default is `14`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the RSI calculation (standard version only).
- **Signal Line Settings:**
  - `InpPeriodMA`: The lookback period for the moving average that smooths the RSI line.
  - `InpMethodMA`: The type of moving average to use for smoothing (SMA, EMA, SMMA, LWMA).

## 5. Usage and Interpretation

- **Trend and Momentum Confirmation:** The primary use is to provide a clearer view of momentum. When the signal line is rising, it confirms bullish momentum; when it's falling, it confirms bearish momentum.
- **Signal Generation via Crossovers:**
  - **RSI / Signal Line Crossover:** When the raw RSI line crosses above its moving average, it can be seen as a bullish signal. A cross below is a bearish signal.
  - **Centerline Crossover:** A crossover of the signal line above the 50 level indicates that bulls are in control. A crossover below 50 indicates bears are in control.
- **Oscillator (Histogram):** The histogram provides a clear visual of the relationship between the RSI and its signal line, highlighting the acceleration and deceleration of momentum.
- **Caution:** The smoothing process introduces lag. The signal line will always react slower than the raw RSI. This filtering is its main advantage, but traders should be aware of the delay.
