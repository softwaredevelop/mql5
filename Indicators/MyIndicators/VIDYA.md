# Variable Index Dynamic Average (VIDYA)

## 1. Summary (Introduction)

The Variable Index Dynamic Average (VIDYA) is an adaptive moving average developed by Tushar Chande. It was designed to automatically adjust its smoothing speed based on market momentum, making it more responsive in trending markets and smoother in sideways markets.

Unlike a standard Exponential Moving Average (EMA) which uses a fixed smoothing constant, VIDYA uses the Chande Momentum Oscillator (CMO) to dynamically alter this constant. When momentum is high, VIDYA speeds up and hugs the price more closely. When momentum wanes, it slows down, filtering out more noise.

## 2. Mathematical Foundations and Calculation Logic

VIDYA is a modified Exponential Moving Average where the smoothing factor is multiplied by the absolute value of the Chande Momentum Oscillator (CMO).

### Required Components

- **EMA Period (N):** The base period for the EMA smoothing calculation.
- **CMO Period (M):** The lookback period for the Chande Momentum Oscillator.
- **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate the Chande Momentum Oscillator (CMO):** The CMO measures momentum by summing up positive and negative price changes over a period `M`.
   $\text{Sum Up}_i = \sum \text{Positive Changes over M periods}$
   $\text{Sum Down}_i = \sum \text{Negative Changes over M periods}$
   $\text{CMO}_i = \frac{\text{Sum Up}_i - \text{Sum Down}_i}{\text{Sum Up}_i + \text{Sum Down}_i}$
   The CMO oscillates between -1 and +1.

2. **Calculate the VIDYA:** The VIDYA is calculated recursively, similar to an EMA.
   - First, define the standard EMA smoothing factor, `alpha`:
     $\alpha = \frac{2}{N + 1}$
   - Then, calculate the VIDYA for each bar:
     $\text{VIDYA}_i = (P_i \times \alpha \times \text{Abs}(\text{CMO}_i)) + (\text{VIDYA}_{i-1} \times (1 - \alpha \times \text{Abs}(\text{CMO}_i)))$

The key is the `alpha * Abs(CMO)` term. When momentum is high, `Abs(CMO)` is close to 1, and VIDYA behaves like a standard EMA. When momentum is low, `Abs(CMO)` is close to 0, which dramatically increases the smoothing and makes the VIDYA line flatten out.

## 3. MQL5 Implementation Details

Our MQL5 implementation was refactored to be a completely self-contained, robust, and accurate indicator.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This is our standard practice for indicators with recursive logic to ensure maximum stability.

- **Robust Initialization:** The recursive VIDYA calculation is carefully initialized to prevent floating-point overflows. The **first valid value** of the VIDYA line is calculated using a **manual Simple Moving Average (SMA)** on the source price data. This provides a stable starting point for all subsequent recursive calculations.

- **Self-Contained Logic:** The indicator is completely self-contained. It does not use external handles. The source price is prepared internally using a `switch` block that handles all `ENUM_APPLIED_PRICE` types, and the CMO is calculated via a dedicated helper function.

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps:

  1. **Step 1:** A `price_source[]` array is prepared based on the user's input.
  2. **Step 2:** A single, efficient `for` loop handles the entire VIDYA calculation, including the robust initialization step and the subsequent recursive calculations.

- **Heikin Ashi Variant (`VIDYA_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi price data as the input for both the VIDYA and the underlying CMO calculation.
  - **Behavioral Note:** This version can appear _more responsive_ than the standard version in strong trends. This is because the smoothed Heikin Ashi data produces a very clean, high-momentum signal for the CMO, causing the `Abs(CMO)` value to stay near 1. This keeps the VIDYA at maximum speed, allowing it to closely track the already-smoothed Heikin Ashi trend.

## 4. Parameters

- **CMO Period (`InpPeriodCMO`):** The lookback period for the Chande Momentum Oscillator, which determines the sensitivity of the speed adjustment. Default is `9`.
- **EMA Period (`InpPeriodEMA`):** The base period for the EMA smoothing. This defines the "slowest" speed of the indicator when momentum is high. Default is `12`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation (e.g., `PRICE_CLOSE`).

## 5. Usage and Interpretation

- **Trend Identification:** VIDYA is used as an adaptive trend line. When the price is above the VIDYA and the line is rising, the trend is bullish. When the price is below the line and it is falling, the trend is bearish.
- **Crossover Signals:** Crossovers of the price and the VIDYA line can be used as trade signals. Because it adapts its speed, these signals can be faster than a standard EMA in trending markets and less frequent in ranging markets.
- **Trend Filter:** The key advantage of VIDYA is its ability to flatten out during periods of low momentum (sideways markets). A flat VIDYA line is a clear signal to avoid trend-following strategies. When the line begins to angle up or down sharply, it indicates that momentum is returning to the market.
- **Caution:** While adaptive, VIDYA is still a lagging indicator. It is a tool for trend confirmation and filtering, not for precise market timing.
