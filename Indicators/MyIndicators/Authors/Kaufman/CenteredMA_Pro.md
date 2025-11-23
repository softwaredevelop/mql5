# Centered Moving Average (CMA) Professional

## 1. Summary (Introduction)

The Centered Moving Average (CMA), a concept popularized by J.M. Hurst in his work on cycle analysis, is a specialized analytical tool designed to visually eliminate the inherent lag of a standard moving average on historical data.

Unlike a regular moving average that always lags behind the price, the CMA is mathematically shifted backwards in time. The result is a trendline whose peaks and troughs are perfectly aligned with the cyclical turning points of the price itself.

**Important Note:** The CMA is an **analytical and research tool, not a real-time trading indicator**. Due to its backward-shifting nature, its value cannot be calculated for the most recent bars on the chart.

Our `CenteredMA_Pro` implementation allows the user to apply this centering technique to any of the core moving average types (SMA, EMA, etc.) and supports both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The logic behind the CMA is a simple but powerful two-step process.

### Required Components

* **Period (N):** The lookback period for the moving average.
* **MA Type:** The type of moving average to be calculated (SMA, EMA, etc.).
* **Source Price (P)**.

### Calculation Steps (Algorithm)

1. **Calculate a Standard Moving Average:** First, a standard, lagging moving average (`MA`) is calculated for the entire price history using the selected period `N` and MA type.

2. **Shift the Moving Average Backwards:** The entire calculated `MA` line is then shifted to the left (backwards in time) by a specific amount to align it with the center of the data it was calculated from.
    * $\text{Shift Amount} = \text{Integer}(\frac{N - 1}{2})$
    * $\text{CMA}_t = \text{MA}_{t + \text{Shift Amount}}$

This shifting process is the reason why the CMA line does not extend to the most recent price bar; to calculate the CMA for today, one would need the moving average value from several bars into the future, which is impossible.

## 3. MQL5 Implementation Details

* **Modular Design (Composition):** The `CCenteredMACalculator` does not recalculate the moving average itself. Instead, it **contains an instance** of our universal `CMovingAverageCalculator`. This is a highly efficient use of our modular toolkit.

* **Two-Step Calculation:** In `OnCalculate`, the indicator first calls the internal `CMovingAverageCalculator` to generate the standard, lagging MA into a temporary buffer. It then performs a second loop to shift the data from the temporary buffer into the final, visible indicator buffer.

* **Heikin Ashi Integration:** By leveraging our universal MA engine, the CMA seamlessly supports calculations on Heikin Ashi data.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average.
* **MA Type (`InpMAType`):** A dropdown menu to select the desired moving average type (SMA, EMA, SMMA, LWMA, etc.).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The CMA is a powerful tool for **historical analysis, research, and strategy development**. It should **not** be used for generating real-time entry or exit signals.

### 1. Visual Cycle Identification (Primary Use)

* The CMA's primary function is to provide a perfectly lag-free visualization of past trend cycles. By observing the distance (in bars) between the peaks and troughs of the CMA line, you can get a clear and objective measure of the dominant cycle lengths in a specific market and timeframe.

### 2. Strategy Validation and Backtesting

* The CMA acts as a "perfect" hindsight trendline. It can be used to validate the signals of faster, real-time oscillators.
* **Example:** Place a CMA and an RSI on the chart. Look back at historical data. If the RSI consistently reaches oversold levels (<30) at or very near the troughs of the CMA, it provides strong confirmation that the RSI is well-tuned for identifying cyclical bottoms in that market.

### 3. Educational Tool

* By placing a CMA and a standard `MovingAverage_Pro` with the same period on the chart, you can visually see and measure the exact amount of lag that a normal moving average introduces. This is an excellent way to understand the inherent trade-offs of trend-following indicators.
