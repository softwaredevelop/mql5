# CG Oscillator Professional (Center of Gravity)

## 1. Summary (Introduction)

The Center of Gravity (CG) Oscillator, developed by John Ehlers, is a unique indicator designed to identify market turning points with **essentially zero lag**. It is based on the physical concept of the center of gravity of an object.

By treating the prices over a lookback window as weights on a ruler, the indicator calculates the "balance point" of the recent price action. Ehlers observed that this balance point moves in opposition to the price. By inverting the result, he created a smooth oscillator that is **in-phase with the price swings**, enabling very early identification of potential reversals.

The indicator plots two lines, forming a complete crossover system:

* **CG Line (red):** The main Center of Gravity oscillator value.
* **Signal Line (blue):** The CG line delayed by one bar, which acts as a trigger line.

The result is a fast, smooth, and responsive oscillator for timing entries and exits.

## 2. Mathematical Foundations and Calculation Logic

The CG Oscillator is a FIR (Finite Impulse Response) filter that calculates the position-weighted average of prices over a given period.

### Required Components

* **Period (N):** The lookback period for the calculation.
* **Source Price (P):** The price series used for the calculation (Ehlers' original work uses the Median Price `(H+L)/2`).

### Calculation Steps (Algorithm)

For each bar, the indicator looks back over the last `N` periods.

1. **Calculate Numerator:** Sum the prices, with each price multiplied by its position in the window. The most recent price gets a weight of 1, the next a weight of 2, and so on.
    $\text{Numerator} = \sum_{i=0}^{N-1} (i+1) \times P_{i}$
2. **Calculate Denominator:** Sum the prices over the window without any weighting.
    $\text{Denominator} = \sum_{i=0}^{N-1} P_{i}$
3. **Calculate Final CG Value:** The final value is the negative ratio of the two sums. The negative sign is used to bring the oscillator in phase with the price.
    $\text{CG} = - \frac{\text{Numerator}}{\text{Denominator}}$
4. **Signal Line Generation:** The Signal Line is simply the CG line's value from one bar prior.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`CG_Oscillator_Calculator.mqh`):** The entire calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on the Median Price of smoothed Heikin Ashi data.
* **FIR-based Logic:** The CG Oscillator is a non-recursive (FIR) filter. Its calculation at any given bar depends only on the last `N` prices, giving it a finite "memory."
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure stability and accuracy.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period (`N`) for the center of gravity calculation. Ehlers' recommendation is to set this to **half the length of the dominant market cycle**. A good starting point for most intraday charts is **10**.
  * A shorter period makes the indicator faster and more responsive to small swings.
  * A longer period makes the indicator smoother and responsive only to larger swings.
* **Source (`InpSource`):** Selects between `Standard` and `Heikin Ashi` candles. The Median Price of the selected candle type will be used.

## 5. Usage and Interpretation

The CG Oscillator is a **timing indicator for cycle reversals**. Its primary signal is the crossover of its two lines.

**Important Note:** Unlike many other oscillators, the CG Oscillator **does not have a fixed horizontal axis or a meaningful zero line**. Its values "float" depending on the absolute price level of the instrument. Therefore, strategies based on zero-line crosses or fixed overbought/oversold levels are not applicable here.

### **1. Signal Line Crossover (Primary Strategy)**

This is the most direct and Ehlers-recommended way to use the indicator.

* **Buy Signal:** The **red CG line crosses above the blue Signal line**. This indicates that the market's "balance point" is shifting towards more recent, rising prices, signaling the start of an upswing.
* **Sell Signal:** The **red CG line crosses below the blue Signal line**. This indicates the balance point is shifting towards falling prices, signaling the start of a downswing.

### **2. Use with a Trend Filter (Highly Recommended)**

Due to its high responsiveness and "zero-lag" nature, the CG Oscillator can produce many signals in a choppy market. It is most effective when its signals are filtered by the primary trend.

* **Uptrend Rule:** In a clear uptrend (e.g., price is above a 200-period EMA or a long-period SuperSmoother), only take **Buy signals** from the CG Oscillator. These signals can be used to time entries at the end of pullbacks.
* **Downtrend Rule:** In a clear downtrend, only take **Sell signals**. These signals can be used to time short entries at the end of corrective rallies.

By combining the CG Oscillator's precise timing with a robust trend filter, traders can create a powerful system for entering trades in the direction of the main market momentum.
