# Band-Stop Filter Professional

## 1. Summary (Introduction)

> **Part of the Ehlers Filter Family**
>
> This indicator is a member of a family of advanced digital filters described in John Ehlers' article, "The Ultimate Smoother."
>
> * [Ehlers Smoother Pro](./Ehlers_Smoother_Pro.md): Features the **SuperSmoother** and **UltimateSmoother**.
> * [Band-Pass Filter](./BandPass_Filter_Pro.md): An oscillator that **isolates** a specific market cycle.
> * **Band-Stop Filter:** A unique filter that **removes** a specific market cycle from the price data.

The Band-Stop Filter, developed by John Ehlers, is a unique analytical tool that functions as the logical opposite of a Band-Pass filter. While a Band-Pass filter isolates a specific range of market cycles, the Band-Stop filter **removes (or "notches out")** a specific range of cycles, leaving all other components (the long-term trend and very short-term noise) intact.

The result is a filtered price line that looks similar to the original price but with a specific cyclical component "erased." Its primary purpose is not to generate direct trading signals, but to serve as an **analytical tool for identifying the market's dominant cycle period**.

## 2. Mathematical Foundations and Calculation Logic

The Band-Stop filter is conceptually created by subtracting a Band-Pass filter's output from the original price data.
$\text{BandStop} = \text{Price} - \text{BandPass}(\text{Price})$

Our implementation uses this robust, definition-true method. It internally calculates a 2-pole Band-Pass filter and subtracts its value from the source price on each bar.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`BandStop_Calculator.mqh`):** The entire calculation, including the internal Band-Pass filter, is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** The calculation involves a recursive filter. To ensure absolute stability, the indicator employs a **full recalculation** on every `OnCalculate` call.

## 4. Parameters

* **Period (`InpPeriod`):** The **center period** of the market cycle that you want to remove.
* **Bandwidth (`InpBandwidth`):** A value between 0.0 and 0.5 that controls the "width" of the frequency band to be removed. A smaller value (e.g., 0.05) removes a very narrow, specific cycle. A larger value (e.g., 0.3) removes a wider range of cycles around the center period. Ehlers suggests a starting value of **0.1**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The Band-Stop Filter is primarily an **analytical tool**, not a direct signal generator. Its main use case, as described by Ehlers, is to identify the dominant cycle in the market.

**Dominant Cycle Identification Strategy:**

1. **Create a "Bank" of Filters:** Apply multiple instances of the `BandStop_Filter_Pro` indicator to the same chart.
2. **Vary the `Period`:** Set each instance to a different `Period` value, covering a range of likely cycle lengths (e.g., one instance with `Period=20`, another with `Period=25`, a third with `Period=30`, and so on).
3. **Identify the Smoothest Line:** Observe the output of all the filters. The instance that produces the **smoothest, least cyclical line** is the one that has successfully identified and removed the market's dominant cycle. The `Period` of that specific instance is your measured dominant cycle period.

**What to do with this information?**

Once you have identified the dominant cycle period (e.g., 30 bars), you can use this information to **tune other, cycle-dependent indicators** for optimal performance. For example:

* Set the period of a **Stochastic** or **RSI** to half the dominant cycle (15).
* Set the `Fundamental Period` of the **Fourier Series** indicator to the dominant cycle (30).
* Set the `DominantCycle` parameter of the **MADH** indicator to the dominant cycle (30).

By using the Band-Stop filter in this analytical way, you can adapt your other trading tools to the market's current, measured rhythm.
