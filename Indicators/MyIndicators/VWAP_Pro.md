# Volume Weighted Average Price (VWAP) Professional

## 1. Summary (Introduction)

The Volume Weighted Average Price (VWAP) is a benchmark indicator used by traders, particularly in intraday analysis, to determine the average price a security has traded at throughout a period, based on both price and volume. It provides a much more accurate picture of the "true" average price by giving more weight to price levels with higher trading volume.

A key feature of the VWAP is that it is **periodically reset**, typically at the start of a new day, week, or month.

Our `VWAP_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, and offers selectable reset periods.

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
    The entire calculation logic is encapsulated within a reusable include file. This engine uses an elegant, object-oriented inheritance model (`CVWAPCalculator` and `CVWAPCalculator_HA`) to support both standard and Heikin Ashi data sources without code duplication.

* **Robust Period Reset Logic:** The calculator uses `MqlDateTime` structures to accurately detect the start of a new session, week, or month, ensuring the VWAP resets correctly under all conditions.

* **Clean Gapped-Line Drawing:** To provide a clear and definition-true visual separation between periods, the indicator uses a **"double buffer" technique**. It plots odd-numbered periods (1st day, 3rd day, etc.) and even-numbered periods (2nd day, 4th day, etc.) on two separate, overlapping plot buffers. This creates a distinct visual gap at each reset point and ensures the current, ongoing period is always fully drawn to the last available bar.

* **Intelligent Volume Handling:** The indicator automatically detects if the selected instrument provides **Real Volume**. If a user requests Real Volume on a symbol where it's unavailable (like Forex/CFDs), the indicator will fail to load and print an informative error message, preventing the display of a misleading, incorrectly calculated line.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

## 4. Parameters

* **Reset Period (`InpResetPeriod`):** The period at which the VWAP calculation resets. Options are `Session` (daily), `Week`, and `Month`.
* **Volume Type (`InpVolumeType`):** Allows the user to select between Tick Volume and Real Volume.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the Typical Price calculation (`Standard` or `Heikin Ashi`).

## 5. Usage and Interpretation

* **Benchmark for "Fair Value":** The VWAP is often considered the "true" average price for the period. Price action above the VWAP is generally considered bullish for the session, while price action below is bearish.
* **Dynamic Support and Resistance:** The VWAP line itself acts as a powerful, dynamic level of support or resistance during the trading session.
* **Mean Reversion:** A significant deviation of the price from the VWAP often leads to a reversion back towards it.
* **Execution Benchmark:** Institutional traders often use the VWAP to gauge the quality of their trade executions. Buying below the VWAP or selling above it is considered a good execution.
