# Volume Weighted Average Price (VWAP) Pro

## 1. Summary (Introduction)

The Volume Weighted Average Price (VWAP) is a benchmark indicator used by traders, particularly in intraday analysis, to determine the average price a security has traded at throughout a period, based on both price and volume. It provides a much more accurate picture of the "true" average price by giving more weight to price levels with higher trading volume.

A key feature of the VWAP is that it is **periodically reset**.

Our `VWAP_Pro` implementation is a highly flexible, professional version that offers multiple reset options:

* Standard **Daily, Weekly, or Monthly** periods.
* A **Timezone-Shifted Daily** period, allowing the "day" to be anchored to a specific exchange's midnight (e.g., NYSE) regardless of broker server time.
* A fully **Custom Session** period defined by a specific start and end time.

The indicator also allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The VWAP is the cumulative ratio of the volume-weighted price to the cumulative volume over a given period.

### Required Components

* **Price Data:** The `High`, `Low`, and `Close` of each bar. The **Typical Price** `(H+L+C)/3` is standard.
* **Volume Data:** The volume for each bar.

### Calculation Steps (Algorithm)

1. **Start of a New Period (e.g., new day):** Reset the cumulative values to zero.
2. **For Each Bar within the Period:**
    * Calculate the Typical Price: $\text{TP}_i = \frac{\text{High}_i + \text{Low}_i + \text{Close}_i}{3}$
    * Update the cumulative sums: `Cumulative (TP x Volume) += TP_i \times \text{Volume}_i` and `Cumulative Volume += \text{Volume}_i`
3. **Calculate the VWAP:**
    * $\text{VWAP}_i = \frac{\text{Cumulative (TP * Volume)}}{\text{Cumulative Volume}}$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, object-oriented design to ensure stability, reusability, and a clean visual representation.

* **Modular Calculation Engine (`VWAP_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable `CVWAPCalculator` class. This engine uses an elegant, object-oriented inheritance model (`CVWAPCalculator` and `CVWAPCalculator_HA`) to support both standard and Heikin Ashi data sources without code duplication.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal cumulative variables (`m_cumulative_tpv`, `m_cumulative_vol`) persist their state between ticks. This allows the calculation to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Flexible and Robust Period Reset Logic:** The calculator uses `MqlDateTime` structures to accurately detect the start of a new period.
  * For **Daily, Weekly, and Monthly** periods, it tracks the change in day, week, or month.
  * For **Timezone-Shifted Daily** periods, it applies a user-defined hour offset to each bar's timestamp before checking for the day change.
  * For **Custom Sessions**, it detects when the price enters the user-defined time window.

* **Clean Gapped-Line Drawing:** To provide a clear visual separation between periods, the indicator uses a **"double buffer" technique**. It plots odd-numbered periods and even-numbered periods on two separate, overlapping plot buffers. This creates a distinct visual gap at each reset point.

* **Intelligent Volume Handling:** The indicator automatically detects if the selected instrument provides **Real Volume**. If a user requests Real Volume on a symbol where it's unavailable (like Forex/CFDs), the indicator will fail to load and print an informative error message.

## 4. Parameters

* **Period Settings:**
  * `Reset Period (`InpResetPeriod`): The period at which the VWAP calculation resets.
    * `PERIOD_SESSION`: Resets daily. The start of the "day" can be adjusted with the timezone shift parameter.
    * `PERIOD_WEEK`: Resets at the start of each week (typically Monday 00:00 broker time).
    * `PERIOD_MONTH`: Resets at the start of each month.
    * `PERIOD_CUSTOM_SESSION`: Resets based on the custom start/end times defined below.
  * `Session Timezone Shift (`InpSessionTimezoneShift`): **Only applies if`Reset Period` is `PERIOD_SESSION`**. This allows you to align the daily reset with a specific market's midnight. Enter the time difference in hours between your broker's server and the desired timezone (e.g., if your broker is UTC+3 and you want to align with NYSE which is UTC-4 in summer, the shift is -7).

* **Custom Session (if selected above):**
  * `Custom Session Start (`InpCustomSessionStart`): **Only applies if`Reset Period` is `PERIOD_CUSTOM_SESSION`**. The start time (HH:MM) for the custom VWAP calculation period.
  * `Custom Session End (`InpCustomSessionEnd`): **Only applies if`Reset Period` is `PERIOD_CUSTOM_SESSION`**. The end time (HH:MM) for the custom VWAP calculation period.

* **Calculation Settings:**
  * `Volume Type (`InpVolumeType`): Allows the user to select between`Tick Volume` and `Real Volume`.
  * `Candle Source (`InpCandleSource`): Allows the user to select the candle type for the Typical Price calculation (`Standard` or `Heikin Ashi`).

## 5. Usage and Interpretation

* **Benchmark for "Fair Value":** The VWAP is often considered the "true" average price for the period. Price action above the VWAP is generally considered bullish for the session, while price action below is bearish.
* **Dynamic Support and Resistance:** The VWAP line itself acts as a powerful, dynamic level of support or resistance during the trading session.
* **Mean Reversion:** A significant deviation of the price from the VWAP often leads to a reversion back towards it.
* **Execution Benchmark:** Institutional traders often use the VWAP to gauge the quality of their trade executions. Buying below the VWAP or selling above it is considered a good execution.
