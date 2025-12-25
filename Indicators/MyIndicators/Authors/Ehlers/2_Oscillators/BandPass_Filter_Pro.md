# Band-Pass Filter Professional

## 1. Summary (Introduction)

> **Part of the Ehlers Filter Family**
>
> This indicator is a member of a family of advanced digital filters described in John Ehlers' article, "The Ultimate Smoother." Each filter is designed to provide a superior balance between smoothing and lag compared to traditional moving averages.
>
> * [Ehlers Smoother Pro](./Ehlers_Smoother_Pro.md): A 2-in-1 indicator featuring the **SuperSmoother** (for maximum smoothing) and the **UltimateSmoother** (for near-zero lag).
> * **Band-Pass Filter:** An oscillator that isolates the cyclical components of the market within a specific frequency band.

The Band-Pass Filter, developed by John Ehlers, is an oscillator-style indicator designed to isolate the primary cyclical rhythm of the market. It achieves this by filtering out both very low-frequency movements (long-term trends) and very high-frequency movements (market noise).

The result is a smooth, sine-wave-like oscillator that fluctuates around a zero line, representing the dominant market cycle within a user-defined frequency band. Its primary purpose is to **time entries and exits** by identifying the turning points of these cycles.

## 2. Mathematical Foundations and Calculation Logic

The Band-Pass filter is ingeniously constructed by applying two of Ehlers' other filters in series.

### Calculation Steps (Algorithm)

1. **High-Pass Filtering:** The source price is first passed through a **High-Pass Filter**. This filter is defined by the `Lower Period` input and its purpose is to remove the slow, long-term trend components from the price data. The output of this step is a detrended price series.
2. **Low-Pass Filtering (Smoothing):** The output of the High-Pass filter is then immediately used as the input for a **SuperSmoother Filter**. This second filter is defined by the `Upper Period` input and its purpose is to remove the high-frequency noise from the detrended series.

The final output of this two-stage process is the Band-Pass line, which represents the smoothed price oscillations within the "band" defined by the two periods.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability and performance.

* **Self-Contained Calculator (`BandPass_Calculator.mqh`):** The entire two-stage, recursive calculation is encapsulated within a dedicated, reusable calculator class.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** The internal buffers (for the High-Pass output and the final Band-Pass output) persist their state between ticks. This allows the recursive IIR filters to continue seamlessly from the last known values without re-processing the entire history.

* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.

## 4. Parameters

* **Lower Period (`InpLowerPeriod`):** The period for the initial High-Pass filter. This determines the **longest** cycles that will be filtered out. Ehlers' default is **30**.
* **Upper Period (`InpUpperPeriod`):** The period for the final SuperSmoother filter. This determines the **shortest** cycles (noise) that will be filtered out. Ehlers' default is **15**.
* **Note on Periods:** Ehlers suggests that the separation between the Lower and Upper periods should be at least one "octave" (i.e., the `LowerPeriod` should be at least double the `UpperPeriod`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The Band-Pass Filter can be used as a standalone oscillator for timing, but its true power is unlocked when combined with Ehlers' other smoothers.

### Standalone Usage

* **Zero-Line Crossover:** A cross of the zero line indicates a shift in the short-term cyclical momentum. A cross above zero is bullish; a cross below is bearish.
* **Peaks and Valleys:** The turning points of the oscillator can be used to time entries and exits. A trough turning upwards is a buy signal, while a peak turning downwards is a sell signal.

### Combined Strategy with Ehlers Smoothers (Recommended)

This strategy uses all three filters together for a comprehensive trading approach.

1. **Trend Filter (The "Map"):** Use a long-period **SuperSmoother** (e.g., Period 100) on your chart to define the main trend.
    * If price is above the SuperSmoother, only look for buy signals.
    * If price is below the SuperSmoother, only look for sell signals.
2. **Dynamic S/R (The "Zone"):** Use a short-period **Ultimate Smoother** (e.g., Period 20) as a dynamic support/resistance level.
    * In an uptrend, wait for the price to pull back to the Ultimate Smoother line. This is your potential entry zone.
3. **Entry Trigger (The "Timing"):** Use the **Band-Pass Filter** to time your entry.
    * **Buy Signal:** When the price is in the entry zone (touching the Ultimate Smoother) and the Band-Pass Filter forms a **valley below the zero line and turns up**, it provides a high-probability entry signal in the direction of the main trend.

This combined approach uses each indicator for its intended purpose: the SuperSmoother for trend, the Ultimate Smoother for the entry zone, and the Band-Pass Filter for the precise timing trigger.
