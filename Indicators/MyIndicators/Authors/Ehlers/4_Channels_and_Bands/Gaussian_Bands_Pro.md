# Gaussian Bands Professional

## 1. Summary (Introduction)

The Gaussian Bands indicator is a modern alternative to classic Bollinger Bands, built upon the advanced filtering concepts of John Ehlers.

Traditional Bollinger Bands use a Simple Moving Average (SMA) as their centerline, which introduces significant lag. The Gaussian Bands replace this slow SMA with a **2-Pole Gaussian Filter**, a low-lag smoother that reacts more quickly to price changes while still providing excellent noise reduction.

The result is a set of volatility bands that are more responsive and hug the price more closely than traditional Bollinger Bands, providing more timely signals for mean-reversion and breakout strategies.

## 2. Mathematical Foundations and Calculation Logic

The indicator calculates volatility bands around a Gaussian-filtered centerline.

### Required Components

* **Period (N):** The lookback period for both the centerline calculation and the standard deviation.
* **Multiplier (M):** The number of standard deviations for the bands.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Centerline:** A `N`-period **Gaussian Filter** is calculated on the source price to create the middle band.
2. **Calculate Standard Deviation:** For each bar, the indicator calculates the standard deviation of the source price from the Gaussian centerline over the last `N` periods.
    $\text{StdDev} = \sqrt{\frac{\sum_{i=1}^{N} (P_i - \text{Centerline}_i)^2}{N}}$
3. **Calculate Bands:** The upper and lower bands are calculated by adding and subtracting a multiple of the standard deviation from the centerline.
    * $\text{Upper Band} = \text{Centerline} + (M \times \text{StdDev})$
    * $\text{Lower Band} = \text{Centerline} - (M \times \text{StdDev})$

## 3. MQL5 Implementation Details

* **Modular Architecture:** The `Gaussian_Bands_Calculator` is built on top of our existing, robust `Gaussian_Filter_Calculator`. It instantiates a filter object internally to calculate the centerline, demonstrating the power of reusable code modules.
* **Heikin Ashi Integration:** The indicator fully supports Heikin Ashi data. When selected, both the centerline and the standard deviation are calculated based on the smoothed HA values.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure the stateful calculations are always stable and accurate.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period (`N`) for both the Gaussian filter and the standard deviation calculation. A common value is **20**.
* **Multiplier (`InpMultiplier`):** The number of standard deviations to plot the bands away from the centerline. A common value is **2.0**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

Gaussian Bands can be used in similar ways to traditional Bollinger Bands, but their increased responsiveness provides a different character.

* **Mean Reversion:** In ranging markets, price touching the upper band can be a sell signal, and price touching the lower band can be a buy signal, anticipating a reversion to the Gaussian centerline. Due to the lower lag, these signals will appear more frequently than with standard Bollinger Bands.
* **Volatility Breakout ("Squeeze"):** Look for periods when the bands narrow significantly (a "squeeze"). This indicates low volatility and a potential for a large price move. A subsequent breakout above the upper band or below the lower band can signal the start of a new, strong trend.
* **Trend Following:** In a strong uptrend, the price will often "walk the upper band." Because the Gaussian filter follows the price more closely, pullbacks to the centerline for re-entry may be less frequent than with a slower SMA-based band.
