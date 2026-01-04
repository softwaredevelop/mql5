# CG Oscillator Professional (Center of Gravity)

## 1. Summary (Introduction)

The Center of Gravity (CG) Oscillator, developed by John Ehlers, is a unique indicator designed to identify market turning points with **essentially zero lag**. It is based on the physical concept of the center of gravity of an object.

By treating the prices over a lookback window as weights on a ruler, the indicator calculates the "balance point" of the recent price action. Ehlers observed that this balance point moves in opposition to the price. By inverting the result, he created a smooth oscillator that is **in-phase with the price swings**, enabling very early identification of potential reversals.

**New in Version 2.10:** The indicator now supports two calculation modes:

1. **Original Mode:** Delivers the raw, negative values exactly as described in Ehlers' original paper.
2. **Pro Mode (Default):** Automatically centers the oscillator around **0.0**, making it easier to read without changing the signal geometry.

The indicator plots two lines, forming a complete crossover system:

* **CG Line (red):** The main Center of Gravity oscillator value.
* **Signal Line (blue):** The CG line delayed by one bar, which acts as a trigger line.

## 2. Mathematical Foundations and Calculation Logic

The CG Oscillator is a FIR (Finite Impulse Response) filter that calculates the position-weighted average of prices over a given period.

### Required Components

* **Period (N):** The lookback period for the calculation.
* **Source Price (P):** The price series used for the calculation (Median Price `(H+L)/2`).

### Calculation Steps (Algorithm)

For each bar, the indicator looks back over the last `N` periods.

1. **Calculate Numerator:** Sum the prices, with each price multiplied by its position in the window. The most recent price gets a weight of 1, the next a weight of 2, and so on.
    $$ \text{Numerator} = \sum_{i=0}^{N-1} (i+1) \times P_{i} $$
2. **Calculate Denominator:** Sum the prices over the window without any weighting.
    $$ \text{Denominator} = \sum_{i=0}^{N-1} P_{i} $$
3. **Calculate Raw CG Value:** The raw value is the negative ratio of the two sums.
    $$ \text{CG}_{\text{raw}} = - \frac{\text{Numerator}}{\text{Denominator}} $$

### Mode Differences

* **Original Mode:** Returns $\text{CG}_{\text{raw}}$. The values will be negative and centered around $-(N+1)/2$.
* **Pro Mode:** Adds an offset to center the oscillator around zero.
    $$ \text{CG}_{\text{pro}} = \text{CG}_{\text{raw}} + \frac{N+1}{2} $$

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`CG_Oscillator_Calculator.mqh`):** The entire calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on the Median Price of smoothed Heikin Ashi data.
* **Incremental Optimization:** The indicator uses `prev_calculated` to optimize performance, recalculating only new bars while maintaining mathematical precision.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period (`N`) for the center of gravity calculation. Ehlers' recommendation is to set this to **half the length of the dominant market cycle**. A good starting point for most intraday charts is **10**.
* **Source (`InpSource`):** Selects between `Standard` and `Heikin Ashi` candles.
* **Original Mode (`InpOriginalMode`):**
  * `true`: Uses the strict Ehlers formula (Negative values).
  * `false`: Centers the oscillator around 0.0 for better readability.

## 5. Usage and Interpretation

The CG Oscillator is a **timing indicator for cycle reversals**. Its primary signal is the crossover of its two lines.

### **1. Signal Line Crossover (Primary Strategy)**

This is the most direct and Ehlers-recommended way to use the indicator.

* **Buy Signal:** The **red CG line crosses above the blue Signal line**. This indicates that the market's "balance point" is shifting towards more recent, rising prices.
* **Sell Signal:** The **red CG line crosses below the blue Signal line**. This indicates the balance point is shifting towards falling prices.

### **2. Center Line Reference (Original Mode vs. Pro Mode)**

Understanding where the "neutral" state lies is crucial for assessing whether the market is extended.

**Pro Mode:**
The neutral line is always **0.0**. Values above 0 suggest bullish momentum; values below 0 suggest bearish momentum.

**Original Mode:**
The neutral line "floats" depending on the **Period** selected. It is calculated as $-(Period + 1) / 2$. If you use Original Mode, you may want to manually draw a horizontal line at the following levels to visualize the center:

| Period (N) | Recommended Center Line Level |
| :---: | :---: |
| **8** | **-4.5** |
| **9** | **-5.0** |
| **10** | **-5.5** |
| **11** | **-6.0** |
| **12** | **-6.5** |
| **13** | **-7.0** |

    Formula: Center = -(Period + 1) / 2

### **3. Use with a Trend Filter (Highly Recommended)**

Due to its high responsiveness and "zero-lag" nature, the CG Oscillator can produce many signals in a choppy market. It is most effective when its signals are filtered by the primary trend.

* **Uptrend Rule:** In a clear uptrend, only take **Buy signals** (Red crosses above Blue).
* **Downtrend Rule:** In a clear downtrend, only take **Sell signals** (Red crosses below Blue).
