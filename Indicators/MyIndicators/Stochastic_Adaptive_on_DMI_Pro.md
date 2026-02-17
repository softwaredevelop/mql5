# Stochastic Adaptive on DMI Pro (Indicator)

## 1. Summary (Introduction)

**Stochastic Adaptive on DMI Pro** is an innovative composite indicator designed to solve the "noise vs. lag" dilemma in momentum trading. It applies the Adaptive Stochastic algorithm directly to the **Directional Movement Index (DMI)** oscillator.

This creates a "Smart Oscillator" that not only tells you the momentum of the trend (via DMI) but also dynamically adjusts its own speed based on how stable that trend is. It is the ultimate tool for filtering false signals in choppy markets while remaining ultra-responsive during strong breakouts.

## 2. Methodology & Pure Logic

This implementation follows the **"Pure Logic"** principle:

* **Source:** The DMI Oscillator (Difference between +DI and -DI).
* **Adaptivity:** The Efficiency Ratio (Noise Filter) is calculated **on the DMI curve itself**, not on the price chart.

This means if the DMI curve is smooth (Clean Momentum), the Stochastic speeds up to catch entries. If the DMI curve is erratic (Choppy Momentum), the Stochastic slows down to filter out fake crosses.

### Processing Steps

1. **DMI Calculation:** Computes standard Directional Movement (+DI/-DI).
2. **DMI Oscillator:** Creates a single line `(PDI - NDI)` representing net trend strength.
3. **Efficiency Ratio (ER):** Measures the "smoothness" of the DMI Oscillator line.
4. **Dynamic Period:** Adjusts the Stochastic lookback window based on the ER.
5. **Stoch Calculation:** Computes %K and %D on the DMI Oscillator using the dynamic period.

## 3. MQL5 Implementation Details

* **Engine (`Stochastic_Adaptive_on_DMI_Calculator.mqh`):**
  * **Composition:** Combines `CDMIEngine` for the source data and `CMovingAverageCalculator` for signal smoothing.
  * **Optimization:** Uses persistent buffers for the DMI Oscillator and ER values, allowing for O(1) incremental updates on every tick.
* **Factory Pattern:** Automatically swaps the underlying DMI engine to a Heikin Ashi optimized version if `InpCandleSource` is set to `CANDLE_HEIKIN_ASHI`.

## 4. Parameters

* **DMI Settings:**
  * `InpDMIPeriod`: The baseline period for trend detection (Default: `10`).
  * `InpOscType`: Formula choice (`+DI minus -DI` or vice versa).
* **Adaptive Settings (The Brain):**
  * `InpErPeriod`: Lookback for measuring DMI smoothness (Default: `10`).
  * `InpMinStochPeriod`: Fastest allowed speed (for strong trends) (Default: `5`).
  * `InpMaxStochPeriod`: Slowest allowed speed (for excessive noise) (Default: `30`).
* **Stochastic Settings:**
  * `InpSlowingK`: Smoothing for the main line.
  * `InpDPeriod`: Period for the Signal line crossover.

## 5. Usage Strategy

This indicator is a "Pulse Detector" for trends.

1. **Trend Continuation (Pullbacks):**
    * In a strong Uptrend (Price > EMA), wait for the Stoch DMI to drop below 20 (oversold) and cross back up. Because it's adaptive, it won't signal until the DMI momentum actually stabilizes.
2. **Divergence:**
    * If Price makes a higher high, but Stoch DMI makes a lower high, it indicates that the *internal momentum structure* is breaking down, even if price looks fine. High probability reversal signal.
3. **Crosses:**
    * **Main Line > Signal Line:** Bullish Momentum building.
    * **Main Line < Signal Line:** Bearish Momentum building.
