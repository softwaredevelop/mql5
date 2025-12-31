# Chaikin Oscillator (CHO) Professional

## 1. Summary (Introduction)

The Chaikin Oscillator (CHO) is a momentum indicator developed by Marc Chaikin. It is an "indicator of an indicator," as it is derived from the Accumulation/Distribution Line (ADL). The CHO measures the momentum of the ADL by comparing a fast and a slow moving average of the ADL.

Its primary purpose is to anticipate changes in the direction of the ADL, and by extension, to signal shifts in buying and selling pressure.

Our `CHO_Pro` implementation is a unified, professional version that allows the underlying ADL calculation to be based on either **standard** or **Heikin Ashi** candles, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The Chaikin Oscillator is calculated by subtracting a slow moving average of the Accumulation/Distribution Line from a fast moving average of the ADL.

### Required Components

* **Accumulation/Distribution Line (ADL):** The underlying cumulative money flow indicator.
* **Fast MA Period:** The period for the shorter-term MA of the ADL (standard is 3).
* **Slow MA Period:** The period for the longer-term MA of the ADL (standard is 10).
* **MA Method:** The type of moving average to use (classic is EMA).

### Calculation Steps (Algorithm)

1. **Calculate the Accumulation/Distribution Line (ADL):** First, the full ADL data series is calculated.

    * $\text{Money Flow Multiplier (MFM)} = \frac{(\text{Close} - \text{Low}) - (\text{High} - \text{Close})}{\text{High} - \text{Low}}$
    * $\text{Money Flow Volume (MFV)} = \text{MFM} \times \text{Volume}$
    * $\text{ADL}_i = \text{ADL}_{i-1} + \text{MFV}_i$

2. **Calculate the Fast and Slow MAs of the ADL:** Compute two separate moving averages on the ADL data series.
    $\text{FastMA}_{\text{ADL}} = \text{MA}(\text{ADL}, \text{Fast Period})$
    $\text{SlowMA}_{\text{ADL}} = \text{MA}(\text{ADL}, \text{Slow Period})$

3. **Calculate the Chaikin Oscillator:** Subtract the Slow MA from the Fast MA.
    $\text{CHO}_i = \text{FastMA}_{\text{ADL}, i} - \text{SlowMA}_{\text{ADL}, i}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a highly modular, component-based design to ensure accuracy, reusability, and maintainability.

* **Component-Based Design (Composition):**
    The CHO calculator (`CHO_Calculator.mqh`) orchestrates three powerful engines:
    1. **ADL Engine:** It reuses the `AD_Calculator.mqh` to compute the underlying Accumulation/Distribution Line.
    2. **Fast MA Engine:** It uses the `MovingAverage_Engine.mqh` to calculate the Fast MA of the ADL.
    3. **Slow MA Engine:** It uses another `MovingAverage_Engine.mqh` instance to calculate the Slow MA of the ADL.
    This ensures mathematical consistency across the entire suite and eliminates code duplication.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations.

* **Object-Oriented Logic:**
  * The Heikin Ashi version (`CCHOCalculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the ADL module.

## 4. Parameters

* **Fast Period (`InpFastPeriod`):** The period for the shorter-term MA of the ADL. (Default: `3`).
* **Slow Period (`InpSlowPeriod`):** The period for the longer-term MA of the ADL. (Default: `10`).
* **MA Method (`InpMaMethod`):** The type of moving average to use for the Fast and Slow MAs. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `EMA`).
* **Volume Type (`InpVolumeType`):** Allows the user to select between Tick Volume and Real Volume for the underlying ADL calculation.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the underlying ADL calculation (`Standard` or `Heikin Ashi`).

## 5. Usage and Interpretation

* **Zero Line Crossovers:** This is the most direct signal from the CHO.
  * **Bullish Crossover:** When the oscillator crosses above the zero line, it indicates that buying pressure (accumulation) is strengthening.
  * **Bearish Crossover:** When the oscillator crosses below the zero line, it indicates that selling pressure (distribution) is strengthening.
* **Divergence:** This is the CHO's most powerful signal.
  * **Bullish Divergence:** Price makes a lower low, but the CHO makes a higher low. This suggests that selling pressure is waning despite the lower price, often foreshadowing a bottom.
  * **Bearish Divergence:** Price makes a higher high, but the CHO makes a lower high. This suggests that the rally is not supported by strong buying pressure and may be nearing exhaustion.
* **Caution:** The Chaikin Oscillator is a momentum indicator. It should be used in conjunction with price action analysis or trend-following tools to confirm signals.
