# LinReg R-Squared Pro (Indicator)

## 1. Summary

**LinReg R-Squared Pro** is a specialized trend-filtering indicator. It measures the statistical reliability of the current price trend.

Instead of just telling you if the price is going up or down (like a Moving Average), it calculates the **Coefficient of Determination ($R^2$)**, which answers the question: *"How well does the current price action fit a perfect straight line?"*

## 2. Methodology & Logic

The indicator performs a **Linear Regression** on a rolling window of past prices and extracts key statistical metrics.

### R-Squared ($R^2$) - The Main Histogram

* **Formula:** Standard statistical $R^2$ calculation (Least Squares Method).
* **Range:** 0.0 to 1.0.
* **Interpretation:**
  * **$R^2 > 0.7$ (Trend):** The market is in a strong, linear trend. The "noise" is low compared to the direction. Trend-following strategies (e.g., Pullback entries) have the highest probability of success here.
  * **$R^2 < 0.3$ (Chop):** The market has no direction. Prices are scattered randomly around the mean. Avoid trend trades; use Mean Reversion strategies.

### Slope (Data Window Only)

* The indicator also calculates the **Slope** of the regression line (price change per bar). This indicates the *direction* and *velocity* of the trend but is not drawn on the chart to keep it clean.

## 3. MQL5 Implementation Details

* **Engine:** Powered by the extended `CLinearRegressionCalculator` class (v4.00), which now supports rolling statistical analysis in addition to channel drawing.
* **Optimization:** It uses efficient "Sum of Squares" caching to calculate the regression parameters ($a, b, r^2$) in real-time without re-iterating the entire history unnecessarily.

## 4. Parameters

* `InpPeriod`: The lookback window for the regression analysis (Default: `20`).
* `InpTrendLevel`: The threshold for defining a "Strong Trend" (Default: `0.7`).

## 5. Usage in Trading

1. **Trend Confirmation:** Do not enter a breakout trade unless the $R^2$ histogram is rising and green (> 0.7).
2. **Trend Exhaustion:** If prices are making new highs, but the $R^2$ histogram starts falling (divergence), the trend is losing its linearity and becoming unstable/volatile. A reversal or consolidation is likely.
3. **Choppy Market Filter:** If the histogram is Gray (< 0.3), stay out of trend trades entirely.
