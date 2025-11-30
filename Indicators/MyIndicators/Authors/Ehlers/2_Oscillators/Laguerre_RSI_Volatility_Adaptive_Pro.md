# Laguerre RSI Volatility-Adaptive Pro

## 1. Summary (Introduction)

> **Part of the Laguerre Indicator Family**
>
> This indicator is the companion oscillator to the [Laguerre Filter Volatility-Adaptive Pro](./Laguerre_Filter_Volatility_Adaptive_Pro.md). It applies the same volatility-based adaptation logic to the Laguerre RSI.

The `Laguerre_RSI_Volatility_Adaptive_Pro` is a highly responsive momentum oscillator. Unlike standard oscillators that use a fixed speed, this indicator **dynamically adjusts its sensitivity** based on market volatility.

* **During Breakouts (High Volatility):** The indicator detects the surge in price movement and automatically increases its speed. This allows the RSI to reach overbought/oversold levels much faster, confirming the strength of the move.
* **During Consolidation (Low Volatility):** The indicator slows down, smoothing out noise and reducing false signals in choppy markets.

This creates an oscillator that is perfectly synchronized with the market's "pulse," providing sharp, timely signals exactly when they are needed.

## 2. Mathematical Foundations and Calculation Logic

The indicator shares its adaptive engine with the Volatility-Adaptive Filter.

### Calculation Steps (Algorithm)

1. **Calculate Adaptive Alpha:** The indicator first calculates the volatility-based `alpha` (gamma) using the same logic as the filter:
    * `Diff = Abs(Price - PrevFilter)`
    * `Mid = Normalize(Diff)`
    * `Alpha = Median(Mid)`
2. **Apply to Laguerre RSI:** This dynamic `Alpha` is then used to update the four internal components (`L0`...`L3`) of the Laguerre RSI.
3. **Calculate RSI:** The final RSI value is derived from these components:
    * $\text{RSI}_i = 100 \times \frac{cu}{cu + cd}$
4. **Signal Line:** An optional signal line (SMA, EMA, etc.) is calculated on the final RSI values.

## 3. MQL5 Implementation Details

* **Dedicated Calculator (`Laguerre_RSI_Volatility_Calculator.mqh`):** The logic is encapsulated in a specialized engine that maintains its own state. It runs a parallel "shadow" filter solely to calculate the volatility `alpha`, ensuring the RSI reacts independently of any other indicator on the chart.
* **Optimized Incremental Calculation:** The indicator employs a sophisticated incremental algorithm with persistent buffers, ensuring **O(1) complexity** per tick.
* **Heikin Ashi Integration:** Fully supports calculation on Heikin Ashi data via the `_HA` class.

## 4. Parameters

* **Volatility Settings:**
  * **`InpPeriod1`:** The lookback period for determining the range of the price difference. Default: **20**.
  * **`InpPeriod2`:** The lookback period for smoothing the calculated alpha. Default: **5**.
* **Signal Line Settings:**
  * **`InpDisplayMode`:** Toggle signal line visibility.
  * **`InpSignalPeriod`:** Period for the signal line.
  * **`InpSignalMAType`:** Type of moving average for the signal line.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

This oscillator is designed for traders who need speed and precision.

* **Rapid Reversals:** Because the indicator speeds up during volatility, it can identify "V-shaped" reversals very effectively. A sharp cross out of the overbought (80) or oversold (20) zone is a high-probability signal.
* **Trend Strength:** In a strong trend, the indicator will pin to the extreme (0 or 100) and stay there. This is not a sell signal; it confirms that volatility is high and the trend is strong.
* **Signal Line Cross:** The addition of a signal line allows for classic momentum crossover strategies, but with the added benefit of the adaptive engine filtering out noise during low-volatility periods.
