# Trend Score Pro (Indicator)

## 1. Summary

**Trend Score Pro** is a context-layer indicator designed to measure the strength and stability of a trend relative to market volatility. Instead of simply showing a moving average, it quantifies **"how far"** the price is from that average (in ATR units) and **"how fast"** that average is rising or falling.

This creates a normalized "Score" that allows you to compare trend strength across different assets (e.g., comparing BTCUSD trend strength with EURUSD trend strength objectively).

## 2. Methodology

The indicator visualizes two key metrics:

### A. Trend Score (Histogram)

* **Formula:** `(Price - DSMA) / ATR`
* **Meaning:** Measures the deviation of price from the trend baseline.
  * **Score > 1.0 (Green):** Price is extended above equilibrium. Strong Bull Trend.
  * **Score < -1.0 (Red):** Price is extended below equilibrium. Strong Bear Trend.
  * **Score ~ 0.0 (Gray):** Price is hugging the line. Range/Choppy market.

### B. Trend Slope (Line)

* **Formula:** `(DSMA_Current - DSMA_Prev) / ATR`
* **Meaning:** Measures the acceleration of the trend itself.
  * If the **Histogram is High** but the **Slope Line is Falling**, it indicates a "Divergence" or loss of momentum, even if the price is still high. This is an early warning signal of trend exhaustion.

## 3. MQL5 Implementation Details

* **Engine:** Utilizing `CDSMACalculator` for the underlying trend baseline (John Ehlers' Deviation Scaled Moving Average) and `CATRCalculator` for normalization.
* **Metrics Tool:** Uses the standardized `CalculateDeviation` logic to ensure consistency with the `Market_Scanner_Pro` script.

## 4. Parameters

* `InpDSMAPeriod`: Lookback for the Trend Baseline (Default: 40).
* `InpATRPeriod`: Lookback for Volatility Normalization (Default: 14).
* `InpSlopeLookback`: How many bars back to compare for slope calculation (Default: 5).
* `InpScoreThresh`: The level at which the histogram changes color to indicate a "Strong Trend" (Default: 1.0).
