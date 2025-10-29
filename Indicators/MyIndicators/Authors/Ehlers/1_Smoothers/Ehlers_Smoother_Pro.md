# Ehlers Smoother Professional

## 1. Summary (Introduction)

> **Part of the Ehlers Filter Family**
>
> This indicator is a member of a family of advanced digital filters described in John Ehlers' article, "The Ultimate Smoother." Each filter is designed to provide a superior balance between smoothing and lag compared to traditional moving averages.
>
> * **Ehlers Smoother Pro:** A 2-in-1 indicator featuring the **SuperSmoother** (for maximum smoothing) and the **UltimateSmoother** (for near-zero lag).
> * [Band-Pass Filter](./BandPass_Filter_Pro.md): An oscillator that isolates the cyclical components of the market.
> * [Ehlers Smoother Momentum Pro](./Ehlers_Smoother_Momentum_Pro.md): The oscillator version of this smoother.

The Ehlers Smoother Pro is a versatile, "two-in-one" indicator that implements two of John Ehlers' most advanced digital filters: the **SuperSmoother** and the **UltimateSmoother**.

The user can choose between the two filter types based on their trading style and needs:

1. **SuperSmoother:** An optimized, second-order (2-pole) Butterworth filter. Its primary goal is to provide **maximum smoothing** with less lag than a traditional moving average of equivalent smoothing power. It is Ehlers' recommendation as a direct replacement for the EMA.
2. **UltimateSmoother:** A unique filter created by mathematically subtracting a High-Pass filter's response from the original price data. Its primary goal is to achieve **near-zero lag** in the trend component of the price, at the cost of slightly less smoothing.

This indicator serves as a high-fidelity, responsive trendline for modern algorithmic and discretionary trading.

## 2. Mathematical Foundations and Calculation Logic

Both filters are recursive Infinite Impulse Response (IIR) filters and use coefficients derived from the user-selected `Period` to define their characteristics.

### SuperSmoother

The SuperSmoother is a 2-pole Butterworth filter optimized for reduced lag. Its recursive formula depends on the two previous filter values (`Filt[1]`, `Filt[2]`) and the average of the last two prices (`P[0]`, `P[1]`).
$\text{Filt}_i = c_1 \times \frac{P_i + P_{i-1}}{2} + c_2 \times \text{Filt}_{i-1} + c_3 \times \text{Filt}_{i-2}$

### UltimateSmoother

The UltimateSmoother is conceptually derived by subtracting a High-Pass filter from the price itself. Ehlers provides a closed-form recursive equation that achieves this result efficiently. It depends on the two previous filter values and the last three price points.
$\text{Filt}_i = (1-c_1)P_i + (2c_1-c_2)P_{i-1} - (c_1+c_3)P_{i-2} + c_2\text{Filt}_{i-1} + c_3\text{Filt}_{i-2}$

The coefficients `c1, c2, c3` are calculated based on the `Period` input.

## 3. MQL5 Implementation Details

* **Unified Calculator (`Ehlers_Smoother_Calculator.mqh`):** The complex, recursive calculations for both filter types are encapsulated within a single, dedicated calculator class. A user input determines which formula is executed.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Robust State Management:** In accordance with our core principles for highly sensitive recursive filters, the calculation is handled within a **stateful internal helper class**. The `Calculate` method uses dedicated internal variables (`f1`, `f2`) to maintain the filter's state (the previous two values), ensuring maximum stability and preventing desynchronization.
* **Definition-True Initialization:** The filter is carefully "warmed up" by setting the initial output values to the raw price for the first few bars, exactly as described in Ehlers' original EasyLanguage code. This provides a stable starting point for the recursive calculation.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call. This, combined with the robust internal state management, guarantees a stable and accurate output under all conditions.

## 4. Parameters

* **Smoother Type (`InpSmootherType`):** Allows the user to select which filter to display.
  * `SUPERSMOOTHER`: Selects the filter focused on maximum smoothing.
  * `ULTIMATESMOOTHER`: Selects the filter focused on near-zero lag.
* **Period (`InpPeriod`):** The "critical period" of the filter, which controls its responsiveness. A longer period results in a smoother, slower filter, while a shorter period results in a faster, more responsive one. A good starting point is **20**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The choice between the two smoothers depends on your primary goal.

### Using the SuperSmoother (Focus on Clarity)

The SuperSmoother is best used as a high-quality replacement for any traditional moving average, especially for **trend identification**.

* A long-period SuperSmoother (e.g., 100) provides a very clean and reliable baseline for the primary trend.

### Using the Ultimate Smoother (Focus on Speed)

The Ultimate Smoother excels where responsiveness is critical, making it an excellent tool for identifying **dynamic support/resistance zones**.

* Because it has minimal lag, it can be used to time entries at the exact end of a pullback. When the price touches the Ultimate Smoother and turns, the signal is immediate.

### Combined Strategy with Smoother Momentum (Advanced)

The filter's true potential is unlocked when used with its companion oscillator, the **[Ehlers Smoother Momentum Pro](./Ehlers_Smoother_Momentum_Pro.md)**. A key predictive relationship exists between them:

* **The Momentum Oscillator's zero-cross predicts the Smoother's turning point.**
  * When the `Smoother Momentum` oscillator crosses **above its zero line**, it provides an early warning that the `Ehlers Smoother` on the main chart is about to form a **trough (a bottom)**.
  * When the `Smoother Momentum` oscillator crosses **below the zero line**, it provides an early warning that the `Ehlers Smoother` is about to form a **peak (a top)**.

This relationship allows a trader to use the momentum oscillator as a **leading indicator** to anticipate the turning points of the smoother, lagging filter on the price chart.

### Combined Strategy with the Band-Pass Filter (Recommended)

The true power of the Ehlers Filter Family is unlocked when the three filters are used together in a comprehensive trading strategy.

1. **Trend Filter (The "Map"):** Use a long-period **SuperSmoother** (e.g., Period 100) to define the main trend.
    * If price is above the SuperSmoother, only look for buy signals.
    * If price is below the SuperSmoother, only look for sell signals.
2. **Dynamic S/R (The "Zone"):** Use a short-period **Ultimate Smoother** (e.g., Period 20) as a dynamic support/resistance level.
    * In an uptrend, wait for the price to pull back to the Ultimate Smoother line. This is your potential entry zone.
3. **Entry Trigger (The "Timing"):** Use the **[Band-Pass Filter](./BandPass_Filter_Pro.md)** to time your entry.
    * **Buy Signal:** When the price is in the entry zone (touching the Ultimate Smoother) and the Band-Pass Filter forms a **valley below the zero line and turns up**, it provides a high-probability entry signal in the direction of the main trend.

This combined approach uses each indicator for its intended purpose: the SuperSmoother for **trend**, the UltimateSmoother for the **entry zone**, and the Band-Pass Filter for the **precise timing trigger**.
