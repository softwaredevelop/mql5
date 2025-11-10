# Moving Average Professional

## 1. Summary (Introduction)

The `MovingAverage_Pro` is a universal, "all-in-one" moving average indicator designed for maximum flexibility and efficiency. It consolidates the four most fundamental moving average types into a single, powerful tool, allowing the user to switch between them with a simple dropdown menu.

The available moving average types are:

* **SMA** (Simple Moving Average)
* **EMA** (Exponential Moving Average)
* **SMMA** (Smoothed Moving Average)
* **LWMA** (Linear Weighted Moving Average)

As part of our professional indicator suite, it fully supports calculations based on either **standard** or **Heikin Ashi** price data, providing a consistent and powerful tool for any analysis style.

## 2. Mathematical Foundations and Calculation Logic

Each moving average type offers a different balance between smoothing and responsiveness. Our implementation is "definition-true" to the standard formulas used in technical analysis.

### SMA (Simple Moving Average)

The SMA is an unweighted arithmetic mean of the last `N` prices. It gives equal weight to all data points, resulting in a smooth line ideal for identifying long-term trends.

$\text{SMA}_t = \frac{1}{N} \sum_{i=0}^{N-1} P_{t-i}$

Where:

* $P_t$ is the price at the current bar.
* $N$ is the moving average period.

### EMA (Exponential Moving Average)

The EMA is a weighted average that applies more weight to recent prices, making it react more quickly to new information. It is calculated recursively.

The smoothing factor, `alpha` ($\alpha$), is calculated as:
$\alpha = \frac{2}{N + 1}$

The EMA is then calculated as:
$\text{EMA}_t = (P_t \times \alpha) + (\text{EMA}_{t-1} \times (1 - \alpha))$

* **Initialization:** The first value of the EMA series ($\text{EMA}_{N-1}$) is calculated as a Simple Moving Average of the first `N` prices.

### SMMA (Smoothed Moving Average)

The SMMA, also known as Wilder's Smoothing, is a specialized moving average with a longer "memory" than an EMA. It is also calculated recursively and is ideal for filtering out market noise.

The formula is:
$\text{SMMA}_t = \frac{(\text{SMMA}_{t-1} \times (N-1)) + P_t}{N}$

* **Initialization:** Similar to the EMA, the first value of the SMMA series is calculated as a Simple Moving Average of the first `N` prices.

### LWMA (Linear Weighted Moving Average)

The LWMA applies linearly more weight to recent prices. The most recent price gets the highest weight, and the weight decreases linearly for older prices.

The formula is:
$\text{LWMA}_t = \frac{\sum_{i=0}^{N-1} P_{t-i} \times (N-i)}{\sum_{j=1}^{N} j}$

Where the denominator is the sum of the weights (e.g., for a 3-period LWMA, the weights are 3, 2, 1, and the sum is 6).

## 3. MQL5 Implementation Details

This indicator is a prime example of our modular and efficient design philosophy.

* **Universal Calculation Engine (`MovingAverage_Engine.mqh`):**
    The entire calculation logic for all four MA types is encapsulated within a single, reusable engine file. This centralized approach eliminates code duplication, simplifies maintenance, and ensures mathematical consistency across our entire indicator suite.

* **User-Selectable Type via Enum:** The indicator uses an `input ENUM_MA_TYPE` parameter, which creates a user-friendly dropdown menu in the settings window. The user's selection is passed directly to the universal engine, which then performs the correct calculation.

* **Object-Oriented Design (Inheritance):**
    A `CMovingAverageCalculator` base class and a `CMovingAverageCalculator_HA` derived class are used to cleanly separate the logic for standard and Heikin Ashi price sources. The child class only overrides the data preparation method, inheriting the entire calculation logic.

* **Dynamic Naming:** The indicator's name on the chart and in the Data Window automatically updates to reflect the user's current selections (e.g., "EMA HA(50)", "SMA(200)").

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average calculation.
* **MA Type (`InpMAType`):** A dropdown menu to select the desired moving average type (SMA, EMA, SMMA, LWMA).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

Moving averages are one of the most fundamental tools in technical analysis.

* **Trend Identification:** The primary use is to identify the direction of the trend.
  * When the price is consistently above the moving average and the line is sloping upwards, the trend is considered bullish.
  * When the price is consistently below the moving average and the line is sloping downwards, the trend is considered bearish.
* **Dynamic Support and Resistance:** In a trending market, the moving average line itself often acts as a dynamic level of support (in an uptrend) or resistance (in a downtrend), providing potential entry points on pullbacks.
* **Crossover Signals:** A common strategy involves using two instances of the `MovingAverage_Pro` indicator with different periods (e.g., a fast 50-period EMA and a slow 200-period EMA).
  * A "Golden Cross" (fast MA crosses above slow MA) is a bullish signal.
  * A "Death Cross" (fast MA crosses below slow MA) is a bearish signal.
