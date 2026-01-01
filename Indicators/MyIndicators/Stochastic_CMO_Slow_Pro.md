# Stochastic CMO Slow Professional

## 1. Summary (Introduction)

The `StochCMO_Slow_Pro` is an advanced "momentum-of-momentum" oscillator. It applies the classic Slow Stochastic formula not to price, but to the output of the **Chande Momentum Oscillator (CMO)**.

This creates a unique analytical tool that measures overbought and oversold conditions in the market's "pure" momentum itself. While the standard Stochastic RSI measures the momentum of a smoothed momentum (RSI), the Stochastic CMO measures the momentum of a more raw, direct momentum (CMO).

The result is a highly responsive oscillator that can provide very early signals of momentum exhaustion. It consists of two lines:

* **%K Line:** The main oscillator line.
* **%D Line:** A moving average of the %K line, serving as a signal line.

## 2. Mathematical Foundations and Calculation Logic

The calculation is a sequential, three-stage process.

### Required Components

* **CMO Period (N):** The lookback period for the base CMO calculation.
* **Stochastic Periods:** %K Period, Slowing Period, and %D Period.
* **Source Price (P)**.

### Calculation Steps (Algorithm)

1. **Calculate the Chande Momentum Oscillator (CMO):** First, the standard CMO is calculated over period `N`, resulting in a value series oscillating between -100 and +100.
    $\text{CMO}_t = 100 \times \frac{\text{Sum Up}_t - \text{Sum Down}_t}{\text{Sum Up}_t + \text{Sum Down}_t}$

2. **Apply the Stochastic Formula to the CMO:** The `CMO` series is now used as the input for a standard Slow Stochastic calculation.
    * **Calculate Fast %K:**
        $\text{Highest High} = \text{Highest value of CMO over the \%K Period}$
        $\text{Lowest Low} = \text{Lowest value of CMO over the \%K Period}$
        $\text{Fast \%K} = 100 \times \frac{\text{CMO}_t - \text{Lowest Low}}{\text{Highest High} - \text{Lowest Low}}$
    * **Calculate Slow %K (Main Line):** The `Fast %K` series is smoothed using the selected moving average type over the `Slowing Period`.
        $\text{Slow \%K} = \text{MA}(\text{Fast \%K}, \text{Slowing Period})$
    * **Calculate %D (Signal Line):** The `Slow %K` series is smoothed again using the selected moving average type over the `%D Period`.
        $\text{\%D} = \text{MA}(\text{Slow \%K}, \text{\%D Period})$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Full Engine Integration:**
    The calculator (`Stochastic_CMO_Slow_Calculator.mqh`) orchestrates three powerful engines:
    1. **CMO Engine:** It reuses the `CMO_Calculator.mqh` to compute the base Chande Momentum Oscillator.
    2. **Slowing Engine:** It uses the `MovingAverage_Engine.mqh` to smooth the Raw %K.
    3. **Signal Engine:** It uses another `MovingAverage_Engine.mqh` instance to calculate the %D line.
    This ensures mathematical consistency and allows for advanced smoothing types (like DEMA or TEMA).

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers (CMO, Raw %K) persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations.

* **Object-Oriented Logic:**
  * The Heikin Ashi version (`CStochasticCMOSlowCalculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the CMO module.

## 4. Parameters

* **CMO Period (`InpCMOPeriod`):** The lookback period for the base Chande Momentum Oscillator.
* **%K Period (`InpKPeriod`):** The lookback period for finding the highest/lowest values of the CMO.
* **Slowing Period (`InpSlowingPeriod`):** The period for the first smoothing of the raw %K line.
* **%D Period (`InpDPeriod`):** The period for smoothing the main %K line to create the signal line.
* **Applied Price (`InpSourcePrice`):** The source price for the base CMO calculation.
* **Slowing MA Type (`InpSlowingMAType`):** The MA type for the %K slowing. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**.
* **%D MA Type (`InpDMAType`):** The MA type for the %D signal line. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**.

## 5. Usage and Interpretation

The StochCMO is a highly sensitive oscillator. Its signals should be interpreted in the context of the broader market trend.

* **Comparison to StochRSI:**
  * **StochCMO (This indicator):** Is based on the "raw" momentum of the CMO. Its signals are **faster and more responsive**, but can also be more "jagged" or "noisy." It excels at identifying the very first signs of momentum exhaustion.
  * **StochRSI:** Is based on the smoothed momentum of the RSI. Its signals are **smoother and more rounded**, making them potentially more reliable for confirming larger momentum shifts, but they may appear later.

* **Overbought/Oversold Levels:**
  * **Values > 80 (Overbought):** Indicates that the raw bullish momentum has been extremely strong and may be overextended. This can be a very early warning of a potential bearish reversal.
  * **Values < 20 (Oversold):** Indicates that raw bearish momentum has been extreme and may be exhausted, signaling a potential bullish reversal.

* **Crossovers:**
  * When the **%K line (blue) crosses above the %D line (red)**, it signals a bullish shift in the momentum-of-momentum.
  * When the **%K line (blue) crosses below the %D line (red)**, it signals a bearish shift.

* **Strategy:** Due to its high sensitivity, the StochCMO is particularly useful for **scalping** or for **timing entries within an established trend**. For example, in a strong uptrend, a dip of the StochCMO into the oversold zone (<20) followed by a bullish crossover can signal an excellent entry point on a pullback.
