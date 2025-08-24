# Bollinger Bands®

## 1. Summary (Introduction)

Bollinger Bands® are a technical analysis tool developed by John Bollinger in the 1980s. They are a type of volatility channel, consisting of three lines plotted in relation to a security's price.

- A **Middle Band**, which is a simple moving average (SMA).
- An **Upper Band**, typically two standard deviations above the middle band.
- A **Lower Band**, typically two standard deviations below the middle band.

The primary purpose of Bollinger Bands is to provide a relative definition of high and low prices. By definition, prices are high at the upper band and low at the lower band. This concept can be used to identify potential overbought and oversold conditions, gauge the strength of a trend, and spot potential breakouts.

## 2. Mathematical Foundations and Calculation Logic

The indicator's strength lies in its use of standard deviation, which allows the bands to automatically adapt to market volatility.

### Required Components

- **Period (N):** The lookback period for both the moving average and the standard deviation calculation (e.g., 20).
- **Standard Deviation (σ):** A statistical measure of volatility or dispersion.
- **Multiplier (M):** The number of standard deviations to shift the bands away from the middle line (e.g., 2.0).
- **Source Price (P):** The price series used for the calculation (e.g., Close).

### Calculation Steps (Algorithm)

1. **Calculate the Middle Band:** Compute a Simple Moving Average (SMA) of the source price over the period `N`.
   $\text{Middle Band}_i = \text{SMA}(P, N)_i$

2. **Calculate the Standard Deviation:** For each bar, calculate the standard deviation of the source price over the same period `N`.
   $\sigma_i = \sqrt{\frac{\sum_{k=i-N+1}^{i} (P_k - \text{Middle Band}_i)^2}{N}}$

3. **Calculate the Upper and Lower Bands:** Add and subtract a multiple of the standard deviation from the middle band.
   $\text{Upper Band}_i = \text{Middle Band}_i + (M \times \sigma_i)$
   $\text{Lower Band}_i = \text{Middle Band}_i - (M \times \sigma_i)$

## 3. MQL5 Implementation Details

Our MQL5 implementations were refactored to be completely self-contained, robust, and accurate.

- **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within the `OnCalculate` function. This is our standard practice to ensure maximum stability and prevent calculation errors.

- **Fully Manual Calculations:** To guarantee 100% accuracy and consistency within our `non-timeseries` calculation model, all calculations are performed manually. The indicators are completely independent of the `<MovingAverages.mqh>` standard library.

  - The **Middle Band (SMA)** is calculated using an efficient **sliding window sum** technique, which is significantly faster than recalculating the sum in every iteration.
  - The **Standard Deviation** is calculated manually for each bar according to its mathematical definition.

- **Integrated Calculation Loop:** The `OnCalculate` function uses a single, efficient `for` loop to perform all calculations. Within each iteration, it first updates the SMA, then calculates the standard deviation based on that SMA, and finally computes the upper and lower bands.

- **Heikin Ashi Variant (`BollingerBands_HeikinAshi.mq5`):**
  - Our toolkit also includes a "pure" Heikin Ashi version of this indicator. The calculation logic is identical, but it uses the smoothed Heikin Ashi price data (e.g., `ha_close`) as its input for both the SMA and the standard deviation calculations.
  - This results in a channel that reflects the volatility of the underlying Heikin Ashi trend rather than the raw market price. The bands are often smoother and can provide a different perspective on trend and volatility.

## 4. Parameters

- **BB Period (`InpBBPeriod`):** The lookback period for the middle line SMA and the standard deviation calculation. The standard is `20`.
- **Deviation (`InpBBDeviation`):** The multiplier for the standard deviation. The standard is `2.0`.
- **Applied Price (`InpAppliedPrice`):** The source price used for the calculation. The standard is `PRICE_CLOSE`.

## 5. Usage and Interpretation

- **"Walking the Bands":** In a strong uptrend, prices will frequently touch or "ride" the upper band. In a strong downtrend, they will ride the lower band. A move away from the bands can signal a weakening of the trend.
- **Mean Reversion (in Ranges):** In a sideways or ranging market, a move to the upper band can be seen as overbought and a potential short opportunity, while a move to the lower band can be seen as oversold and a potential long opportunity.
- **The Squeeze:** When the bands narrow significantly, it indicates a period of low volatility. This "squeeze" often precedes a period of high volatility and a potential price breakout. Traders often watch for the price to close outside the bands after a squeeze as a trading signal.
- **Breakouts:** A strong close outside the bands can signal the start of a new trend. However, it's important to watch for "head fakes," where the price quickly reverses back inside the bands.
- **Caution:** Bollinger Bands are a versatile tool but should not be used in isolation. The signals they provide should be confirmed with other indicators or forms of analysis.
