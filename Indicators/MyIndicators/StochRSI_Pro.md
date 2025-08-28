# Stochastic RSI Pro

## 1. Summary (Introduction)

The Stochastic RSI Pro is an enhanced, "indicator of an indicator" that applies the flexible **Stochastic Pro** formula to a **Relative Strength Index (RSI)** data series instead of standard price data.

While the standard StochRSI uses a fixed smoothing method, this "Pro" version grants the trader full control over the oscillator's behavior by allowing the independent selection of the moving average type (**SMA, EMA, SMMA, LWMA**) for both the %K and %D lines. This allows for a vast range of customization, from replicating the classic textbook definition to creating entirely new, hybrid oscillators.

## 2. Mathematical Foundations and Calculation Logic

The StochRSI Pro follows the structure of the Slow Stochastic but uses an RSI series as its input and allows for generalized moving average calculations.

### Required Components

- **RSI Data Series:** The underlying data, calculated with a specific period.
- **%K Period:** The lookback period for the initial Stochastic calculation on the RSI data.
- **Slowing Period & MA Type:** The period and MA type for the first smoothing step (%K line).
- **%D Period & MA Type:** The period and MA type for the second smoothing step (the signal line).

### Calculation Steps (Algorithm)

1. **Calculate the RSI:** First, the standard RSI is calculated for a given period.
   $\text{RSI}_i = \text{RSI}(\text{Price}, \text{RSI Period})_i$

2. **Calculate the Raw %K (Fast StochRSI):** Apply the Stochastic formula to the RSI data series.
   $\text{Raw \%K}_i = 100 \times \frac{\text{RSI}_i - \text{Lowest(RSI, \%K Period)}}{\text{Highest(RSI, \%K Period)} - \text{Lowest(RSI, \%K Period)}}$

3. **Calculate the %K Line (Slowing):** The Raw %K line is smoothed using the selected `Slowing Period` and `Slowing MA Type`.
   $\text{\%K}_i = \text{MA}(\text{Raw \%K}, \text{Slowing Period}, \text{Slowing MA Type})_i$

4. **Calculate the %D Line (Signal):** The signal line is a moving average of the %K line, using the selected `%D Period` and `%D MA Type`.
   $\text{\%D}_i = \text{MA}(\text{\%K}, \text{\%D Period}, \text{\%D MA Type})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementations are self-contained, robust, and highly flexible indicators built upon our established coding principles.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function for maximum stability.

- **Robust MA Calculations:** All moving average calculations for the Slowing and %D steps are performed **manually**. This guarantees 100% accuracy and consistency within our `non-timeseries` model. Recursive MA types (EMA, SMMA) are carefully initialized with a manual Simple Moving Average (SMA).

- **Clear, Staged Calculation:** The `OnCalculate` function is structured into clear, sequential steps, each handled by a dedicated `for` loop, making the logic easy to follow.

- **Efficient RSI Source:**
  - The standard version (`StochRSI_Pro.mq5`) uses a handle to MQL5's built-in `iRSI` indicator for efficiency and guaranteed accuracy.
  - The Heikin Ashi version (`StochRSI_Pro_HeikinAshi.mq5`) uses our custom `CHeikinAshi_RSI_Calculator` from the `HeikinAshi_Tools.mqh` library to generate a "pure" Heikin Ashi RSI data series.

## 4. Parameters

- **`InpRSIPeriod`**: The lookback period for the underlying RSI calculation.
- **`InpKPeriod`**: The lookback period for the Stochastic calculation on the RSI data.
- **`InpSlowingPeriod`**: The period for the first smoothing step (%K line).
- **`InpSlowingMAType`**: The MA type for the first smoothing step.
- **`InpDPeriod`**: The period for the signal line smoothing (%D line).
- **`InpDMAType`**: The MA type for the signal line.
- **`InpAppliedPrice`**: The source price for the underlying RSI calculation.

## 5. Usage and Interpretation

The interpretation of the StochRSI Pro is identical to the standard StochRSI, but its sensitivity can be adjusted.

- **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions. It reaches these levels more frequently than the standard RSI.
- **Crossovers:** The crossover of the %K line and the %D signal line can be used to generate trade signals. A bullish crossover in oversold territory is a strong signal, and a bearish crossover in overbought territory is a strong signal.
- **Divergence:** Divergences between the oscillator and the price can signal weakening momentum and potential reversals.
- **Caution:** Due to its nature as an "indicator of an indicator," the StochRSI is very sensitive and can produce many signals in choppy markets. It is best used for confirmation alongside other, broader trend analysis tools.
