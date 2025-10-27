# Ehlers Bands Professional

## 1. Summary (Introduction)

The Ehlers Bands indicator is a modern and more responsive alternative to classic Bollinger Bands, built upon the advanced filtering concepts of John Ehlers.

Traditional Bollinger Bands use a Simple Moving Average (SMA) as their centerline, which introduces significant lag. The Ehlers Bands replace this slow SMA with a user-selectable, high-performance Ehlers filter, providing a choice between two distinct behaviors:

1. **SuperSmoother Centerline (Default):** Uses the SuperSmoother filter to create a very smooth, stable centerline. The resulting bands are excellent for identifying the primary trend and gauging overall volatility, similar to classic Bollinger Bands but with less lag.
2. **UltimateSmoother Centerline (Advanced):** Uses the near-zero-lag UltimateSmoother filter. This creates extremely responsive, tight bands that hug the price closely, highlighting periods of sharp expansion and contraction in volatility.

This flexibility allows traders to choose between a smoother, more traditional band behavior and a highly responsive, low-lag alternative within a single indicator.

## 2. Mathematical Foundations and Calculation Logic

The indicator calculates volatility bands around a dynamically adapting centerline.

### Required Components

* **Centerline Type:** The choice of Ehlers filter (SuperSmoother or UltimateSmoother).
* **Period (N):** The lookback period for both the centerline calculation and the standard deviation.
* **Multiplier (M):** The number of standard deviations for the bands.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Centerline:** A `N`-period **SuperSmoother** or **UltimateSmoother** is calculated on the source price to create the middle band.
2. **Calculate Standard Deviation:** For each bar, the indicator calculates the standard deviation of the source price from the centerline over the last `N` periods.
    $\text{StdDev} = \sqrt{\frac{\sum_{i=1}^{N} (P_i - \text{Centerline}_i)^2}{N}}$
3. **Calculate Bands:** The upper and lower bands are calculated by adding and subtracting a multiple of the standard deviation from the centerline.
    * $\text{Upper Band} = \text{Centerline} + (M \times \text{StdDev})$
    * $\text{Lower Band} = \text{Centerline} - (M \times \text{StdDev})$

## 3. MQL5 Implementation Details

* **Modular Architecture:** The `Ehlers_Bands_Calculator` is built on top of our existing, robust `Ehlers_Smoother_Calculator`. It instantiates a smoother object internally to calculate the centerline, demonstrating the power of reusable code modules.
* **Heikin Ashi Integration:** The indicator fully supports Heikin Ashi data. When selected, both the centerline and the standard deviation are calculated based on the smoothed HA values.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure the stateful calculations are always stable and accurate.

## 4. Parameters

* **Centerline Type (`InpCenterlineType`):** Allows the user to select the filter for the middle band.
  * `SUPERSMOOTHER`: Provides a very smooth centerline, resulting in wider, more stable bands. **Recommended for most strategies.**
  * `ULTIMATESMOOTHER`: Provides a near-zero-lag centerline, resulting in tighter, more reactive bands.
* **Period (`InpPeriod`):** The lookback period (`N`) for both the centerline filter and the standard deviation calculation. A common value is **20**.
* **Multiplier (`InpMultiplier`):** The number of standard deviations to plot the bands away from the centerline. A common value is **2.0**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

Ehlers Bands can be used in similar ways to traditional Bollinger Bands, but the choice of centerline provides unique advantages.

### **1. SuperSmoother Mode (Enhanced Bollinger Bands)**

This mode is a direct, superior replacement for standard Bollinger Bands.

* **Mean Reversion:** In ranging markets, price touching the upper band can be a sell signal, and price touching the lower band can be a buy signal, anticipating a reversion to the SuperSmoother centerline.
* **Volatility Breakout ("Squeeze"):** Look for periods when the bands narrow significantly (a "squeeze"). This indicates low volatility and a potential for a large price move. A subsequent breakout above the upper band or below the lower band can signal the start of a new, strong trend.
* **Trend Following:** In a strong uptrend, the price will often "walk the upper band." Pullbacks to the SuperSmoother centerline can be used as entry points.

### **2. UltimateSmoother Mode (Fast, Reactive Bands)**

This mode offers a different perspective due to the centerline's responsiveness.

* **Extremely Tight Bands:** The bands will hug the price very closely. This makes them less useful for traditional mean-reversion strategies.
* **"Pop" Signals:** Their primary use is to identify sharp, fast moves. When the price "pops" or breaks out of the very tight bands, it signals a sudden increase in momentum. This can be used as an entry trigger in the direction of the breakout, with the expectation of a quick, short-term move.

For most traders, the **SuperSmoother mode will provide more familiar and versatile signals**, while the UltimateSmoother mode is a specialized tool for analyzing short-term volatility bursts.
