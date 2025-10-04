# Money Flow Index (MFI) Professional

## 1. Summary (Introduction)

The Money Flow Index (MFI) is a momentum oscillator that measures the strength of money flowing into and out of a security. Developed as a "volume-weighted RSI," it combines both price and volume data to identify overbought or oversold conditions.

Our `MFI_Pro` implementation is a unified, professional version that includes an **optional signal line** and allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The MFI calculation is similar to the RSI, but it uses "Money Flow," which is derived from the Typical Price and Volume.

### Required Components

- **Period (N):** The lookback period for the calculation.
- **Price and Volume Data:** The `High`, `Low`, `Close`, and `Volume` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate the Typical Price (TP):** $\text{TP}_i = \frac{\text{High}_i + \text{Low}_i + \text{Close}_i}{3}$
2. **Calculate the Raw Money Flow (RMF):** $\text{Raw Money Flow}_i = \text{TP}_i \times \text{Volume}_i$
3. **Determine Positive and Negative Money Flow** by comparing the current TP to the previous TP.
4. **Calculate the Money Flow Ratio** by summing the Positive and Negative Money Flows over the period `N`.
5. **Calculate the Money Flow Index (MFI):** $\text{MFI}_i = 100 - \frac{100}{1 + \text{Money Flow Ratio}}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

- **Modular Calculation Engine (`MFI_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  - **`CMFICalculator`**: The base class that performs the full MFI and signal line calculation.
  - **`CMFICalculator_HA`**: A child class that inherits all logic and only overrides the data preparation step to use the Typical Price derived from smoothed Heikin Ashi candles.

- **Selectable Display Mode:** The indicator includes a `Display Mode` input that allows the user to show either the MFI line by itself or the MFI line together with its moving average signal line.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

- **Efficient Calculation:** The summation of Money Flow is handled by an efficient **sliding window sum** technique.

## 4. Parameters

- **MFI Period (`InpMFIPeriod`):** The lookback period for summing the money flows. The standard is `14`.
- **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the Typical Price calculation (`Standard` or `Heikin Ashi`).
- **Volume Type (`InpVolumeType`):** Allows the user to select between Tick Volume and Real Volume.
- **Signal Line Settings:**
  - `InpDisplayMode`: Toggles the visibility of the signal line.
  - `InpMAPeriod`: The lookback period for the signal line.
  - `InpMAMethod`: The type of moving average for the signal line.

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The primary use of the MFI is to identify extreme conditions (typically above 80 and below 20).
- **Divergence:** This is the MFI's most powerful signal. A bullish divergence occurs when price makes a lower low, but the MFI makes a higher low. A bearish divergence is the opposite.
- **Signal Line Crossovers:** If the signal line is enabled, crossovers can provide entry and exit signals, similar to other oscillators.
- **Caution:** In a very strong trend, the MFI can remain in overbought or oversold territory for extended periods.
