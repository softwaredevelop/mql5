# Moving Average Pro

## 1. Summary (Introduction)

The `MovingAverage_Pro` is a universal, "all-in-one" moving average indicator designed for maximum flexibility and efficiency. It consolidates **nine** fundamental and advanced moving average types into a single, powerful tool, allowing the user to switch between them with a simple dropdown menu.

The available moving average types are:

* **SMA** (Simple Moving Average)
* **EMA** (Exponential Moving Average)
* **SMMA** (Smoothed Moving Average)
* **LWMA** (Linear Weighted Moving Average)
* **TMA** (Triangular Moving Average)
* **DEMA** (Double Exponential Moving Average)
* **TEMA** (Triple Exponential Moving Average)
* **VWMA** (Volume-Weighted Moving Average)

As part of our professional indicator suite, it fully supports calculations on either **standard** or **Heikin Ashi** price data, providing a consistent and powerful tool for any analysis style.

## 2. Mathematical Foundations and Calculation Logic

Each moving average type offers a different balance between smoothing and responsiveness. Our implementation is "definition-true" to the standard formulas used in technical analysis.

### SMA (Simple Moving Average)

The arithmetic mean of the last `N` prices. Ideal for identifying long-term trends.
$$\text{SMA}_t = \frac{1}{N} \sum_{i=0}^{N-1} P_{t-i}$$

### EMA (Exponential Moving Average)

A weighted average that applies more weight to recent prices. Calculated recursively.
$$\alpha = \frac{2}{N + 1}$$
$$\text{EMA}_t = (P_t \times \alpha) + (\text{EMA}_{t-1} \times (1 - \alpha))$$

### SMMA (Smoothed Moving Average)

Also known as Wilder's Smoothing. Has a longer "memory" than an EMA.
$$\text{SMMA}_t = \frac{(\text{SMMA}_{t-1} \times (N-1)) + P_t}{N}$$

### LWMA / WMA (Linear Weighted Moving Average / Weighted Moving Average)

Applies linearly decreasing weights from the most recent price to the oldest. WMA is equivalent to LWMA in our suite to ensure direct compatibility with TradingView standards.
$$\text{LWMA}_t = \frac{\sum_{i=0}^{N-1} P_{t-i} \times (N-i)}{\sum_{j=1}^{N} j}$$

### TMA (Triangular Moving Average)

A double-smoothed average (SMA of an SMA) that emphasizes the middle of the data window. Extremely smooth.

### DEMA (Double Exponential Moving Average)

A lag-reduction technique by Patrick Mulloy.
$$\text{DEMA}_t = (2 \times \text{EMA}_1) - \text{EMA}_2$$

### TEMA (Triple Exponential Moving Average)

An advanced lag-reduction technique using triple smoothing.
$$\text{TEMA}_t = (3 \times \text{EMA}_1) - (3 \times \text{EMA}_2) + \text{EMA}_3$$

### VWMA (Volume-Weighted Moving Average)

Integrates trading volume into the calculation. Higher volume bars have a proportionally larger influence on the resulting average, allowing the indicator to track institutional interest and true market consensus.
$$\text{VWMA}_t = \frac{\sum_{i=0}^{N-1} (P_{t-i} \times V_{t-i})}{\sum_{i=0}^{N-1} V_{t-i}}$$

## 3. MQL5 Implementation Details

* **Universal Calculation Engine (`MovingAverage_Engine.mqh`):**
    The core logic is encapsulated in a robust engine that powers multiple indicators in our suite (including Stochastic Pro and MACD Pro).
  * **Versatility:** The engine supports calculations on both standard OHLC data and custom arrays (via `CalculateOnArray`), with advanced offset handling for complex indicators.
  * **Overloaded Volume Interface:** High-precision overload patterns are provided for Volume-sensitive calculations like `VWMA`. If volume data is not passed, the calculator executes a robust fallback mechanism to SMA with a warning print.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** For recursive types (EMA, SMMA, DEMA, TEMA), internal buffers persist their state between ticks, ensuring seamless updates without full recalculation.
  * **Robust Initialization:** The engine includes specific logic to handle the initialization of recursive averages (seeding with SMA) to prevent artifacts at the beginning of the data series.

* **Object-Oriented Design:**
  * A `CMovingAverageCalculator` base class handles the core math.
  * A `CMovingAverageCalculator_HA` derived class handles Heikin Ashi data preparation, ensuring clean separation of concerns.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average calculation.
* **MA Type (`InpMAType`):** Select from SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA, WMA, VWMA.
* **Applied Price (`InpSourcePrice`):** The source price (Standard or Heikin Ashi).

## 5. Usage and Interpretation

* **Trend Identification:**
  * **Bullish:** Price > MA and MA sloping up.
  * **Bearish:** Price < MA and MA sloping down.
* **Dynamic Support/Resistance:** The MA line often acts as a bouncing point for price during trends.
* **Volume Confirmation (VWMA vs SMA):**
  * When **VWMA is above SMA**, it indicates that volume has been higher on bullish closed bars (high institutional demand).
  * When **VWMA is below SMA**, it signifies that volume is backing bearish developments.