# Money Flow Index (MFI)

## 1. Summary (Introduction)

The Money Flow Index (MFI) is a momentum oscillator that measures the strength of money flowing into and out of a security. Developed as a "volume-weighted RSI," it combines both price and volume data to identify overbought or oversold conditions.

Unlike the standard RSI which only considers price, the MFI incorporates volume to provide a clearer picture of the conviction behind price moves. A strong price trend accompanied by high volume is considered more significant than one with low volume. This makes the MFI a powerful tool for gauging trend strength and spotting potential reversals, particularly through divergence signals.

## 2. Mathematical Foundations and Calculation Logic

The MFI calculation is similar to the RSI, but instead of using simple price changes, it uses "Money Flow," which is derived from the Typical Price and Volume.

### Required Components

- **Period (N):** The lookback period for the calculation (e.g., 14).
- **Price and Volume Data:** The `High`, `Low`, `Close`, and `Volume` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate the Typical Price (TP):** For each bar, calculate the average of the high, low, and close.
   $\text{TP}_i = \frac{\text{High}_i + \text{Low}_i + \text{Close}_i}{3}$

2. **Calculate the Raw Money Flow (RMF):** Multiply the Typical Price by the volume for that period.
   $\text{Raw Money Flow}_i = \text{TP}_i \times \text{Volume}_i$

3. **Determine Positive and Negative Money Flow:** Compare the current bar's Typical Price to the previous bar's.

   - If $\text{TP}_i > \text{TP}_{i-1}$, it is considered **Positive Money Flow** ($\text{PMF}_i = \text{RMF}_i$).
   - If $\text{TP}_i < \text{TP}_{i-1}$, it is considered **Negative Money Flow** ($\text{NMF}_i = \text{RMF}_i$).
   - If they are equal, the money flow is zero for that period.

4. **Calculate the Money Flow Ratio:** Sum the Positive and Negative Money Flows over the period `N` and calculate their ratio.
   $\text{Money Flow Ratio} = \frac{\sum_{k=i-N+1}^{i} \text{PMF}_k}{\sum_{k=i-N+1}^{i} \text{NMF}_k}$

5. **Calculate the Money Flow Index (MFI):** Use the ratio to scale the value between 0 and 100.
   $\text{MFI}_i = 100 - \frac{100}{1 + \text{Money Flow Ratio}}$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a self-contained, robust, and mathematically correct representation of the classic MFI.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function to ensure maximum stability and prevent calculation errors.

- **Correct Algorithm:** Unlike the flawed example code provided with MetaTrader, our implementation strictly follows the correct, textbook definition of the MFI, ensuring its results are consistent with other professional charting platforms like TradingView.

- **Efficient Calculation:** The summation of Positive and Negative Money Flow over the lookback period is handled by an efficient **sliding window sum** technique. This avoids nested loops and provides excellent performance.

- **Optional Signal Line:** Our version is enhanced with an optional, user-configurable moving average signal line. The signal line calculation uses our standard, robust, and fully manual `switch` block, which correctly handles all MA types (SMA, EMA, SMMA, LWMA) and their initialization.

- **Heikin Ashi Variant (`MFI_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version. The calculation logic is identical, but it uses the smoothed Heikin Ashi `ha_high`, `ha_low`, and `ha_close` to calculate the Typical Price.
  - This results in a smoother MFI that filters out price noise. It is particularly effective at producing **clearer and more pronounced divergence signals**, as the Heikin Ashi smoothing helps to identify the true underlying momentum faster than standard price data.

## 4. Parameters

- **MFI Period (`InpMFIPeriod`):** The lookback period for summing the money flows. The standard is `14`.
- **Volume Type (`InpVolumeType`):** Allows the user to select between Tick Volume (`VOLUME_TICK`) and Real Volume (`VOLUME_REAL`).
- **Signal Line Settings:**
  - `InpMAPeriod`: The lookback period for the optional signal line.
  - `InpMAMethod`: The type of moving average for the signal line.

## 5. Usage and Interpretation

- **Overbought/Oversold Levels:** The primary use of the MFI is to identify extreme conditions.
  - **Overbought:** Readings above **80** are considered overbought.
  - **Oversold:** Readings below **20** are considered oversold.
- **Divergence:** This is the MFI's most powerful signal.
  - **Bullish Divergence:** Price makes a lower low, but the MFI makes a higher low. This indicates that despite the lower price, selling pressure (volume) is weakening, which can foreshadow a bullish reversal.
  - **Bearish Divergence:** Price makes a higher high, but the MFI makes a lower high. This indicates that the new high is not supported by strong money flow, and buying pressure is weakening, which can foreshadow a bearish reversal.
- **Signal Line Crossovers:** If the optional signal line is used, crossovers can provide entry and exit signals, similar to other oscillators like RSI or CCI.
- **Caution:** In a very strong trend, the MFI can remain in overbought or oversold territory for extended periods. Divergence signals are generally considered more reliable than simple overbought/oversold readings.
