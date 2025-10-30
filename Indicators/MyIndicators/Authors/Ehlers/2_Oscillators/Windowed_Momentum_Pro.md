# Windowed Momentum Professional

## 1. Summary (Introduction)

The Windowed Momentum Pro is an oscillator developed from the concepts in John Ehlers' "Windowing" article. Instead of applying the advanced FIR filters to the price, this indicator applies them to a **momentum source (Close - Open)**.

The indicator calculates a weighted average of the bar-by-bar momentum over a given period, using a selectable **windowing function** (SMA, Triangular, or Hann).

The result is a smooth, zero-mean oscillator that measures the underlying strength and direction of momentum. The use of the **Hann window** is particularly effective, as it creates a much cleaner and less noisy oscillator than a simple momentum calculation.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a weighted moving average of the `Close - Open` value of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Momentum Source:** For each bar, the source data is calculated as `Momentum = Close - Open`.
2. **Apply Windowing Function:** A weighted moving average is calculated on this `Momentum` data series using the selected windowing function (SMA, Triangular, or Hann) over the `N`-period lookback window. The calculation is identical to the `Windowed MA Pro` indicator, but applied to a different data source.

## 3. MQL5 Implementation Details

* **Unified Calculator (`Windowed_MA_Calculator.mqh`):** This indicator uses the exact same, powerful calculator engine as the `Windowed_MA_Pro`. The only difference is that it is initialized in `SOURCE_MOMENTUM` mode.
* **Heikin Ashi Integration:** The indicator fully supports calculation on smoothed Heikin Ashi data (`HA Close - HA Open`).
* **FIR-based Logic:** This is a non-recursive (FIR) filter.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call.

## 4. Parameters

* **Window Type (`InpWindowType`):** Allows the user to select the weighting function: `SMA`, `Triangular`, or `Hann`. **`Hann` is recommended for the smoothest output.**
* **Period (`InpPeriod`):** The lookback period (`N`) for the momentum averaging.
* **Candle Source (`InpCandleSource`):** Selects between `Standard` and `Heikin Ashi` candles.

## 5. Usage and Interpretation

The Windowed Momentum is a classic zero-mean oscillator used for identifying momentum shifts and potential reversals.

* **Zero-Line Crossover:**
  * A cross **above the zero line** indicates that bullish momentum is taking control.
  * A cross **below the zero line** indicates that bearish momentum is dominant.
* **Divergence:** This is one of the most powerful ways to use the indicator.
  * **Bullish Divergence:** Price makes a **new lower low**, but the Windowed Momentum makes a **higher low**. This signals weakening sell pressure and a potential bottom.
  * **Bearish Divergence:** Price makes a **new higher high**, but the Windowed Momentum makes a **lower high**. This signals weakening buy pressure and a potential top.
* **Combined with Windowed MA:** Use the `Windowed_MA_Pro` to define the main trend. Then, use the `Windowed_Momentum_Pro` to time entries. In an uptrend (price > W-MA), look for the W-Momentum to form a valley (ideally below zero) and turn up as a high-probability entry signal.

### **Combined Strategy with Windowed MA (Primary Use)**

This oscillator is designed to be used in conjunction with its companion indicator, the `Windowed_MA_Pro`. The relationship between the two provides a powerful timing signal.

* **The Zero-Cross Predicts the MA's Turning Point:** The most important signal is the crossing of the zero line, as it directly corresponds to the turning points of the `Windowed_MA`.
  * **Buy Signal:** When the `Windowed_Momentum` line crosses **above the zero line**, it signals that the `Windowed_MA` on the main chart is forming a **trough (a bottom)**. This is a signal that the downtrend momentum has ended and an uptrend is beginning.
  * **Sell Signal:** When the `Windowed_Momentum` line crosses **below the zero line**, it signals that the `Windowed_MA` is forming a **peak (a top)**. This indicates the end of uptrend momentum.

This strategy allows a trader to use the Momentum oscillator as a **leading indicator** to anticipate the turning points of the smoother, lagging `Windowed_MA`.
