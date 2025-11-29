# Ehlers Smoother Momentum Pro

## 1. Summary (Introduction)

The Ehlers Smoother Momentum Pro is a versatile oscillator that applies one of John Ehlers' advanced filters—the **SuperSmoother** or the **UltimateSmoother**—to a **momentum source (Close - Open)** instead of the price.

While the standard `Ehlers_Smoother_Pro` provides a smoothed representation of the trend, this indicator isolates and smooths the bar-by-bar momentum. The user can choose which smoothing engine to use, allowing for a trade-off between responsiveness and smoothness in the final oscillator.

* **SuperSmoother Mode (Default):** Creates an exceptionally smooth momentum oscillator that is excellent for identifying the main momentum swings while filtering out minor noise. Its zero-crosses are reliable, albeit slightly lagging, timing signals.
* **UltimateSmoother Mode:** Creates a faster, more responsive momentum oscillator with near-zero lag, which reacts very quickly to changes in momentum.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a smoothed average of the `Close - Open` value of each bar, using one of two advanced recursive filters.

### Calculation Steps (Algorithm)

1. **Calculate Momentum Source:** For each bar, the source data is calculated as `Momentum = Close - Open`.
2. **Apply Ehlers Smoother:** A SuperSmoother or UltimateSmoother filter is calculated on this `Momentum` data series, based on the user's selection.

## 3. MQL5 Implementation Details

* **Unified Calculator (`Ehlers_Smoother_Calculator.mqh`):** This indicator uses the exact same, powerful calculator engine as the `Ehlers_Smoother_Pro`. The only difference is that it is initialized in `SOURCE_MOMENTUM` mode.
* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal momentum buffer (`m_price`) and the output buffer (`filter_buffer`) persist their state between ticks. This allows the recursive IIR filter to continue seamlessly from the last known values without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.
* **Heikin Ashi Integration:** The indicator fully supports calculation on smoothed Heikin Ashi data (`HA Close - HA Open`), leveraging the same optimized engine.

## 4. Parameters

* **Smoother Type (`InpSmootherType`):** Allows the user to select the filter for the momentum calculation: `SUPERSMOOTHER` or `ULTIMATESMOOTHER`.
* **Period (`InpPeriod`):** The critical period of the selected filter, which controls its smoothing and responsiveness.
* **Candle Source (`InpCandleSource`):** Selects between `Standard` and `Heikin Ashi` candles for the `Close - Open` calculation.

## 5. Usage and Interpretation

The Ehlers Smoother Momentum is a zero-mean oscillator used for identifying momentum shifts and potential reversals.

### Standalone Usage

* **Zero-Line Crossover:** This is the primary signal.
  * A cross **above the zero line** indicates that bullish momentum is taking control.
  * A cross **below the zero line** indicates that bearish momentum is dominant.
  * The **SuperSmoother** mode provides smoother, more confirmed crossover signals, while the **UltimateSmoother** mode provides faster, earlier signals.
* **Divergence:** Divergences between the price and the oscillator are powerful reversal signals, particularly clear in the smoother SuperSmoother mode.

### Combined Strategy with Ehlers Smoother (Primary Use)

This oscillator is designed to be used in conjunction with its companion indicator, the `Ehlers_Smoother_Pro`.

* **The Zero-Cross Predicts the Smoother's Turning Point:**
  * **Buy Signal:** When the **Smoother Momentum** line crosses **above the zero line**, it signals that the `Ehlers Smoother` on the main chart is forming a **trough (a bottom)**.
  * **Sell Signal:** When the **Smoother Momentum** line crosses **below the zero line**, it signals that the `Ehlers Smoother` is forming a **peak (a top)**.

This strategy allows a trader to use the momentum oscillator as a **leading indicator** to anticipate the turning points of the smoother, lagging filter on the price chart.
