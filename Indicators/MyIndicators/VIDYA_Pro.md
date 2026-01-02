# Variable Index Dynamic Average (VIDYA) Professional Family

## 1. Summary (Introduction)

The Variable Index Dynamic Average (VIDYA), developed by Tushar Chande, is a sophisticated adaptive moving average that automatically adjusts its speed based on market momentum. It uses the Chande Momentum Oscillator (CMO) to dynamically alter its smoothing factor. When momentum is high, VIDYA becomes more sensitive and follows prices closely. When momentum wanes in a consolidating market, it slows down and smooths out price action.

Our professional implementation is an **indicator family** consisting of two versions, both powered by a single, universal calculation engine:

* **`VIDYA_Pro`:** The classic, single-color implementation that acts as a pure adaptive trend line.
* **`VIDYA_Color_Pro`:** An enhanced version that changes color based on the direction of the underlying momentum (CMO positive or negative), providing an additional layer of visual information.

Both indicators support calculations based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

VIDYA is a modified Exponential Moving Average where the smoothing factor is multiplied by the absolute value of the Chande Momentum Oscillator (CMO).

### Required Components

* **EMA Period (N):** The base period for the EMA smoothing calculation.
* **CMO Period (M):** The lookback period for the Chande Momentum Oscillator.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate the Chande Momentum Oscillator (CMO):** The CMO measures momentum over a period `M`, oscillating between -100 and +100.
    * $\text{Sum Up}_i = \text{Sum of positive price changes over M periods}$
    * $\text{Sum Down}_i = \text{Sum of absolute negative price changes over M periods}$
    * $\text{CMO}_i = 100 \times \frac{\text{Sum Up}_i - \text{Sum Down}_i}{\text{Sum Up}_i + \text{Sum Down}_i}$

2. **Calculate the VIDYA:** The VIDYA is calculated recursively.
    * First, define the standard EMA smoothing factor, `alpha`:
        $\alpha = \frac{2}{N + 1}$
    * Then, calculate the VIDYA for each bar. Note that the formula uses the **absolute value** of the CMO (normalized to a 0-1 range) to adjust the speed, not the direction.
        $\text{VIDYA}_i = (P_i \times \alpha \times \text{Abs}(\frac{\text{CMO}_i}{100})) + (\text{VIDYA}_{i-1} \times (1 - \alpha \times \text{Abs}(\frac{\text{CMO}_i}{100})))$

## 3. MQL5 Implementation Details

Our MQL5 implementation is built on a highly efficient and reusable object-oriented architecture.

* **Universal Calculation Engine (`VIDYA_Calculator.mqh`):**
    A single, powerful engine file contains all the core calculation logic. This eliminates code duplication and ensures that both `VIDYA_Pro` and `VIDYA_Color_Pro` produce identical average values.

* **Composition with CMO Engine:** The VIDYA calculator does not re-implement the CMO logic. Instead, it internally instantiates our lightweight `CMO_Engine.mqh`. This ensures that the momentum measurement is mathematically identical to the standalone CMO indicator, while maintaining high performance.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Efficiency:** The recursive VIDYA calculation continues seamlessly from the last known value without re-processing the entire history.

* **Method Overloading:** The `CVIDYACalculator` class features two versions of the `Calculate` method:
    1. `Calculate(..., double &vidya_buffer[])`: For `VIDYA_Pro`.
    2. `Calculate(..., double &vidya_up_buffer[], double &vidya_down_buffer[])`: For `VIDYA_Color_Pro`.

* **Object-Oriented Design:**
    The engine uses a `CVIDYACalculator` base class and a `CVIDYACalculator_HA` derived class. The child class only overrides the `PreparePriceSeries` method to supply Heikin Ashi data.

## 4. Parameters (`VIDYA_Pro` & `VIDYA_Color_Pro`)

The input parameters are identical for both indicators.

* **CMO Period (`InpPeriodCMO`):** The lookback period for the Chande Momentum Oscillator. (Default: `9`).
* **EMA Period (`InpPeriodEMA`):** The base period for the EMA smoothing. (Default: `12`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. (Standard or Heikin Ashi).

## 5. Usage and Interpretation

### `VIDYA_Pro` (Single Color)

* **Adaptive Trend Line:** Hugs the price during strong trends and flattens out during consolidation.
* **Trend Filter:** A flat or sideways VIDYA line indicates a ranging market.
* **Dynamic Support/Resistance:** Acts as a dynamic level of support/resistance in trending markets.

### `VIDYA_Color_Pro` (Multi-Color)

This version includes all the benefits of the standard `VIDYA_Pro` but adds an immediate visual cue for momentum direction.

* **Green Line:** Bullish momentum (CMO > 0).
* **Red Line:** Bearish momentum (CMO < 0).
* **Confirmation:** A color change can act as an early confirmation of a trend change.
