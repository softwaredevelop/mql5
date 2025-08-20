# Moving Average of RSI (RSIMA)

## 1. Summary (Introduction)

The Moving Average of RSI, often referred to as RSIMA, is a technical indicator that smooths the standard Relative Strength Index (RSI) with a moving average. While the RSI is a powerful momentum oscillator, it can often be volatile, producing sharp movements and "noisy" signals.

By applying a moving average to the RSI line, the RSIMA filters out this short-term noise, providing a smoother line that can make the underlying momentum trend easier to identify. It essentially acts as a signal line for the RSI, similar to how the %D line acts as a signal line for the Stochastic Oscillator.

## 2. Mathematical Foundations and Calculation Logic

The RSIMA is a two-stage indicator. It first calculates the standard RSI and then applies a moving average to the resulting RSI values.

### Required Components

- **RSI (Relative Strength Index):** The underlying momentum oscillator.
- **Moving Average (MA):** The smoothing mechanism applied to the RSI line. This can be a Simple (SMA), Exponential (EMA), Smoothed (SMMA), or Linear Weighted (LWMA) moving average.

### Calculation Steps (Algorithm)

1. **Calculate the RSI:** First, calculate the standard RSI for a given period (e.g., 14) on the source price (e.g., Close). The RSI formula is based on Wilder's smoothing of average gains and average losses.
   $\text{RS}_i = \frac{\text{Wilder's MA}(\text{Up Moves}, \text{RSI Period})_i}{\text{Wilder's MA}(\text{Down Moves}, \text{RSI Period})_i}$
   $\text{RSI}_i = 100 - \frac{100}{1 + \text{RS}_i}$

2. **Calculate the Moving Average of RSI:** Apply the selected moving average type with its specified period to the RSI data series calculated in the first step.
   $\text{RSIMA}_i = \text{MA}(\text{RSI}, \text{MA Period})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation is designed for stability, clarity, and consistency with our existing indicator toolkit.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This is our standard practice for indicators involving recursive calculations (like EMA or SMMA) to ensure maximum stability and prevent errors during timeframe changes or history loading.

- **Leveraging Standard Indicators:** For the initial RSI calculation, we use a handle to MQL5's built-in `iRSI` indicator. This is a robust and efficient method for obtaining the underlying RSI data series. The handle's resources are properly managed and released in the `OnDeinit` function.

- **Robust EMA/SMMA Initialization:** This is the most critical part of the implementation. Standard library functions for recursive MAs can be unstable in a full recalculation model. To guarantee stability, we take control of the initialization process:

  - For EMA and SMMA calculations, the **first value** of the moving average is calculated using a **manual Simple Moving Average (SMA)** on the preceding RSI data.
  - This provides a stable, valid starting point for all subsequent recursive calculations, completely eliminating the risk of floating-point overflows that can occur with uninitialized data.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into two clear, sequential steps:

  1. **Step 1:** The complete RSI data series is retrieved into the `BufferRawRSI` calculation buffer using `CopyBuffer`.
  2. **Step 2:** A single `for` loop calculates the moving average on the `BufferRawRSI` data, utilizing our robust `switch` block to handle the different MA types and their specific initialization needs.

- **Heikin Ashi Variant (`RSI_HeikinAshi.mq5`):**
  - Our toolkit also includes a Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_close` values as the input for the initial RSI calculation.
  - This results in a doubly-smoothed oscillator, ideal for traders who want to focus only on the most significant, sustained momentum shifts.

## 4. Parameters

- **RSI Period (`InpPeriodRSI`):** The lookback period for the underlying RSI calculation. Default is `14`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the RSI calculation (e.g., `PRICE_CLOSE`).
- **MA Period (`InpPeriodMA`):** The lookback period for the moving average that smooths the RSI line. Default is `14`.
- **MA Method (`InpMethod`):** The type of moving average to use for smoothing (SMA, EMA, SMMA, LWMA). Default is `MODE_SMA`.

## 5. Usage and Interpretation

- **Trend and Momentum Confirmation:** The primary use of the RSIMA is to provide a clearer view of momentum. When the RSIMA line is rising, it confirms bullish momentum; when it's falling, it confirms bearish momentum.
- **Signal Generation via Crossovers:**
  - **RSI / RSIMA Crossover:** When the raw RSI line (green) crosses above its moving average (blue), it can be seen as a bullish signal. A cross below is a bearish signal.
  - **Centerline Crossover:** A crossover of the RSIMA line above the 50 level indicates that bulls are in control. A crossover below 50 indicates bears are in control.
- **Smoothed Overbought/Oversold Signals:** The RSIMA line entering the overbought (above 70/80) or oversold (below 30/20) zones provides a more filtered, less frequent signal than the raw RSI.
- **Caution:** The smoothing process introduces lag. The RSIMA will always react slower than the raw RSI. This filtering is its main advantage, but traders should be aware of the delay.
