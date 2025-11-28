# Moving Average Pro

## 1. Summary (Introduction)

The `MovingAverage_Pro` is a universal, "all-in-one" moving average indicator designed for maximum flexibility and efficiency. It consolidates **seven** fundamental and advanced moving average types into a single, powerful tool, allowing the user to switch between them with a simple dropdown menu.

The available moving average types are:

* **SMA** (Simple Moving Average)
* **EMA** (Exponential Moving Average)
* **SMMA** (Smoothed Moving Average)
* **LWMA** (Linear Weighted Moving Average)
* **TMA** (Triangular Moving Average)
* **DEMA** (Double Exponential Moving Average)
* **TEMA** (Triple Exponential Moving Average)

As part of our professional indicator suite, it fully supports calculations on either **standard** or **Heikin Ashi** price data, providing a consistent and powerful tool for any analysis style.

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

### TMA (Triangular Moving Average)

The TMA is a double-smoothed moving average that gives the most weight to the data in the middle of its lookback period. It is extremely smooth and is best used as a long-term trendline or cyclical centerline, not for fast signals. It is calculated by taking an SMA of an SMA.

1. $\text{SMA}_{1_t} = \text{SMA}(P, \text{Ceiling}(\frac{N + 1}{2}))_t$
2. $\text{TMA}_t = \text{SMA}(\text{SMA}_1, \text{Floor}(\frac{N + 1}{2}))_t$

### DEMA (Double Exponential Moving Average)

Developed by Patrick Mulloy, the DEMA is not a simple double-smoothed EMA. It is a lag-reduction technique that combines a single EMA and a double EMA to create a more responsive moving average.

1. $\text{EMA}_{1_t} = \text{EMA}(P, N)_t$
2. $\text{EMA}_{2_t} = \text{EMA}(\text{EMA}_1, N)_t$
3. $\text{DEMA}_t = (2 \times \text{EMA}_{1_t}) - \text{EMA}_{2_t}$

### TEMA (Triple Exponential Moving Average)

Also developed by Patrick Mulloy, the TEMA is an even more advanced lag-reduction technique that uses a triple-smoothing process to create an extremely responsive moving average that stays very close to the price.

1. $\text{EMA}_{1_t} = \text{EMA}(P, N)_t$
2. $\text{EMA}_{2_t} = \text{EMA}(\text{EMA}_1, N)_t$
3. $\text{EMA}_{3_t} = \text{EMA}(\text{EMA}_2, N)_t$
4. $\text{TEMA}_t = (3 \times \text{EMA}_{1_t}) - (3 \times \text{EMA}_{2_t}) + \text{EMA}_{3_t}$

## 3. MQL5 Implementation Details

* **Universal Calculation Engine (`MovingAverage_Engine.mqh`):**
    The entire calculation logic for all **seven** MA types is encapsulated within a single, reusable engine file. This centralized approach eliminates code duplication and simplifies maintenance.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** For recursive types (EMA, SMMA) and complex types (DEMA, TEMA), the internal intermediate buffers (e.g., `ema1`, `ema2`) persist their state between ticks. This allows the calculation to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Efficient EMA Calculation:** The engine uses a dedicated `CalculateEMA` helper function that supports incremental updates. This function is called recursively to efficiently build the DEMA and TEMA.

* **User-Selectable Type via Enum:** The indicator uses an `input ENUM_MA_TYPE` parameter, which creates a user-friendly dropdown menu in the settings window. The user's selection is passed directly to the universal engine.

* **Object-Oriented Design (Inheritance):** A `CMovingAverageCalculator` base class and a `CMovingAverageCalculator_HA` derived class are used to cleanly separate the logic for standard and Heikin Ashi price sources.

* **Dynamic Naming:** The indicator's name on the chart automatically updates to reflect the user's current selections (e.g., "DEMA HA(50)", "TMA(100)").

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period for the moving average calculation.
* **MA Type (`InpMAType`):** A dropdown menu to select the desired moving average type (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

Moving averages are one of the most fundamental tools in technical analysis.

* **Trend Identification:** The primary use is to identify the direction of the trend.
  * When the price is consistently above the moving average and the line is sloping upwards, the trend is considered bullish.
  * When the price is consistently below the moving average and the line is sloping downwards, the trend is considered bearish.
* **Dynamic Support and Resistance:** In a trending market, the moving average line itself often acts as a dynamic level of support (in an uptrend) or resistance (in a downtrend), providing potential entry points on pullbacks.
* **Crossover Signals:** A common strategy involves using two instances of the `MovingAverage_Pro` indicator with different periods (e.g., a fast 50-period EMA and a slow 200-period EMA).
  * A "Golden Cross" (fast MA crosses above slow MA) is a bullish signal.
  * A "Death Cross" (fast MA crosses below slow MA) is a bearish signal.
