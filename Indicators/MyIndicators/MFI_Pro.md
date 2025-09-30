# Money Flow Index (MFI) Professional

## 1. Summary (Introduction)

The Money Flow Index (MFI) is a momentum oscillator that measures the strength of money flowing into and out of a security. Developed as a "volume-weighted RSI," it combines both price and volume data to identify overbought or oversold conditions.

Unlike the standard RSI which only considers price, the MFI incorporates volume to provide a clearer picture of the conviction behind price moves.

Our `MFI_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The MFI calculation is similar to the RSI, but instead of using simple price changes, it uses "Money Flow," which is derived from the Typical Price and Volume.

### Required Components

* **Period (N):** The lookback period for the calculation (e.g., 14).
* **Price and Volume Data:** The `High`, `Low`, `Close`, and `Volume` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate the Typical Price (TP):** For each bar, calculate the average of the high, low, and close.
    $\text{TP}_i = \frac{\text{High}_i + \text{Low}_i + \text{Close}_i}{3}$

2. **Calculate the Raw Money Flow (RMF):** Multiply the Typical Price by the volume for that period.
    $\text{Raw Money Flow}_i = \text{TP}_i \times \text{Volume}_i$

3. **Determine Positive and Negative Money Flow:** Compare the current bar's Typical Price to the previous bar's.
    * If $\text{TP}_i > \text{TP}_{i-1}$, it is **Positive Money Flow** ($\text{PMF}_i = \text{RMF}_i$).
    * If $\text{TP}_i < \text{TP}_{i-1}$, it is **Negative Money Flow** ($\text{NMF}_i = \text{RMF}_i$).

4. **Calculate the Money Flow Ratio:** Sum the Positive and Negative Money Flows over the period `N` and calculate their ratio.
    $\text{Money Flow Ratio} = \frac{\sum_{k=i-N+1}^{i} \text{PMF}_k}{\sum_{k=i-N+1}^{i} \text{NMF}_k}$

5. **Calculate the Money Flow Index (MFI):** Use the ratio to scale the value between 0 and 100.
    $\text{MFI}_i = 100 - \frac{100}{1 + \text{Money Flow Ratio}}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and maintainability.

* **Modular Calculation Engine (`MFI_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **`CMFICalculator`**: The base class that performs the full MFI and signal line calculation on a given source price.
  * **`CMFICalculator_HA`**: A child class that inherits all the complex logic and only overrides the initial data preparation step to use the Typical Price derived from smoothed Heikin Ashi candles. This object-oriented approach eliminates code duplication.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

* **Efficient Calculation:** The summation of Positive and Negative Money Flow is handled by an efficient **sliding window sum** technique.

* **Optional Signal Line:** Our version is enhanced with a user-configurable moving average signal line, with all MA types calculated manually for robustness.

## 4. Parameters

* **MFI Period (`InpMFIPeriod`):** The lookback period for summing the money flows. The standard is `14`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the Typical Price calculation (`Standard` or `Heikin Ashi`).
* **Volume Type (`InpVolumeType`):** Allows the user to select between Tick Volume and Real Volume.
* **Signal Line Settings:**
  * `InpMAPeriod`: The lookback period for the signal line.
  * `InpMAMethod`: The type of moving average for the signal line.

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use of the MFI is to identify extreme conditions.
  * **Overbought:** Readings above **80**.
  * **Oversold:** Readings below **20**.
* **Divergence:** This is the MFI's most powerful signal.
  * **Bullish Divergence:** Price makes a lower low, but the MFI makes a higher low, suggesting selling pressure is weakening.
  * **Bearish Divergence:** Price makes a higher high, but the MFI makes a lower high, suggesting buying pressure is weakening.
* **Signal Line Crossovers:** Crossovers can provide entry and exit signals, similar to other oscillators.
* **Caution:** In a very strong trend, the MFI can remain in overbought or oversold territory for extended periods.
