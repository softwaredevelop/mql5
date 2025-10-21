# Ehlers Smoother Professional

## 1. Summary (Introduction)

The Ehlers Smoother Pro is a versatile, "two-in-one" indicator that implements two of John Ehlers' most advanced digital filters: the **SuperSmoother** and the **Ultimate Smoother**. These filters are designed to overcome the classic dilemma of technical analysis: the trade-off between smoothing and lag. They provide superior alternatives to traditional moving averages like the EMA or SMA.

The user can choose between the two filter types based on their trading style and needs:

1. **SuperSmoother:** An optimized, second-order (2-pole) Butterworth filter. Its primary goal is to provide **maximum smoothing** with less lag than a traditional moving average of equivalent smoothing power. It is Ehlers' recommendation as a direct replacement for the EMA.
2. **Ultimate Smoother:** A unique filter created by mathematically subtracting a High-Pass filter's response from the original price data. Its primary goal is to achieve **near-zero lag** in the trend component of the price, at the cost of slightly less smoothing compared to the SuperSmoother.

This indicator serves as a high-fidelity, responsive trendline for modern algorithmic and discretionary trading.

## 2. Mathematical Foundations and Calculation Logic

Both filters are recursive (IIR - Infinite Impulse Response) and use coefficients derived from the user-selected `Period` to define their characteristics.

### SuperSmoother

The SuperSmoother is a 2-pole Butterworth filter optimized for reduced lag. Its recursive formula depends on the two previous filter values and the average of the last two prices.
$\text{Filt}_i = c_1 \times \frac{P_i + P_{i-1}}{2} + c_2 \times \text{Filt}_{i-1} + c_3 \times \text{Filt}_{i-2}$

### Ultimate Smoother

The Ultimate Smoother is conceptually derived by subtracting a High-Pass filter from an All-Pass filter (the price itself): `Ultimate = Price - HighPass(Price)`. Ehlers provides a closed-form recursive equation that achieves this result efficiently:
$\text{Filt}_i = (1-c_1)P_i + (2c_1-c_2)P_{i-1} - (c_1+c_3)P_{i-2} + c_2\text{Filt}_{i-1} + c_3\text{Filt}_{i-2}$

The coefficients `c1, c2, c3` are calculated based on the `Period` input.

## 3. MQL5 Implementation Details

* **Unified Calculator (`Ehlers_Smoother_Calculator.mqh`):** The complex, recursive calculations for both filter types are encapsulated within a single, dedicated calculator class. A user input determines which formula is executed.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** Both filters are highly state-dependent. To ensure absolute stability and prevent desynchronization errors, the indicator employs a **full recalculation** on every `OnCalculate` call. The recursive state is managed internally within the calculation loop.

## 4. Parameters

* **Smoother Type (`InpSmootherType`):** Allows the user to select which filter to display.
  * `SUPERSMOOTHER`: Selects the filter focused on maximum smoothing.
  * `ULTIMATE_SMOOTHER`: Selects the filter focused on near-zero lag.
* **Period (`InpPeriod`):** The "critical period" of the filter, which controls its responsiveness. A longer period results in a smoother, slower filter, while a shorter period results in a faster, more responsive one. A good starting point is **20**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The choice between the two smoothers depends on your primary goal.

### Using the SuperSmoother (Focus on Clarity)

The SuperSmoother is best used as a high-quality replacement for any traditional moving average.

* **Trend Filtering:** A long-period SuperSmoother (e.g., 100) provides a very clean and reliable baseline for the primary trend.
* **Dynamic Support and Resistance:** Due to its smoothness, the line acts as a strong dynamic S/R level. Entries can be timed when the price pulls back and bounces off the SuperSmoother line in the direction of the main trend.
* **Crossover Systems:** A system using a fast and a slow SuperSmoother will produce fewer, but often more reliable, crossover signals than an equivalent EMA-based system.

### Using the Ultimate Smoother (Focus on Speed)

The Ultimate Smoother excels where responsiveness is critical.

* **Low-Lag Trendline:** It hugs the price very closely, providing an almost instantaneous view of the smoothed price action.
* **Entry Timing on Pullbacks:** Because it has minimal lag, it can be used to time entries at the exact end of a pullback. When the price touches the Ultimate Smoother and turns, the signal is immediate.
* **Confirmation of Price Action:** It can be used to confirm breakouts or changes in short-term momentum more quickly than other moving averages.

**Combined Strategy:** A powerful approach is to use a **long-period SuperSmoother** to define the overall trend and a **short-period Ultimate Smoother** for timing entries. For example, in an uptrend (price > SuperSmoother(100)), a trader could look to buy when the price bounces off the Ultimate Smoother(20).
