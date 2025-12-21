# Ehlers Smoother Momentum Pro

## 1. Summary (Introduction)

The Ehlers Smoother Momentum Pro is a versatile oscillator that applies one of John Ehlers' advanced filters—the **SuperSmoother** or the **UltimateSmoother**—to a **momentum source (Close - Open)** instead of the price.

While the standard `Ehlers_Smoother_Pro` provides a smoothed representation of the trend, this indicator isolates and smooths the bar-by-bar momentum. The user can choose which smoothing engine to use, allowing for a trade-off between responsiveness and smoothness in the final oscillator.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a smoothed average of the `Close - Open` value of each bar, using one of two advanced recursive filters.

### Calculation Steps (Algorithm)

1. **Calculate Momentum Source:** For each bar, the source data is calculated as `Momentum = Close - Open`.
2. **Apply Ehlers Smoother:** A SuperSmoother or UltimateSmoother filter is calculated on this `Momentum` data series, based on the user's selection.

## 3. MQL5 Implementation Details

* **Unified Calculator (`Ehlers_Smoother_Calculator.mqh`):** This indicator uses the exact same, powerful calculator engine as the `Ehlers_Smoother_Pro`. The only difference is that it is initialized in `SOURCE_MOMENTUM` mode.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** The indicator buffer itself acts as the persistent memory for the recursive calculation, ensuring seamless updates without drift or full recalculation.

* **Heikin Ashi Integration:** The indicator fully supports calculation on smoothed Heikin Ashi data (`HA Close - HA Open`).

## 4. Parameters

* **Smoother Type (`InpSmootherType`):** Selects the filter (`SUPERSMOOTHER` or `ULTIMATESMOOTHER`).
* **Period (`InpPeriod`):** The critical period of the selected filter. (Default: `20`).
* **Candle Source (`InpCandleSource`):** Selects between `Standard` and `Heikin Ashi` candles for the `Close - Open` calculation.

## 5. Usage and Interpretation

The Ehlers Smoother Momentum is a zero-mean oscillator used for identifying momentum shifts and potential reversals.

### Standalone Usage

* **Zero-Line Crossover:**
  * **Bullish:** Cross above zero.
  * **Bearish:** Cross below zero.
* **Divergence:** Powerful reversal signal.

### Combined Strategy with Ehlers Smoother (Primary Use)

This oscillator is designed to be used in conjunction with its companion indicator, the `Ehlers_Smoother_Pro`.

* **The Zero-Cross Predicts the Smoother's Turning Point:**
  * **Buy Signal:** Momentum crosses above zero -> Smoother forms a trough.
  * **Sell Signal:** Momentum crosses below zero -> Smoother forms a peak.
