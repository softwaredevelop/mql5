# Moving Average Ribbon MTF Pro

## 1. Summary (Introduction)

The `MovingAverage_Ribbon_MTF_Pro` is a specialized multi-timeframe (MTF) analysis tool designed to project a complete Moving Average Ribbon from a higher timeframe onto your current chart.

It allows you to visualize the trend structure of a **higher, user-selected timeframe** (e.g., seeing the H4 ribbon structure while trading on M15). This provides invaluable context for trend alignment and dynamic support/resistance zones.

## 2. Features

* **4 Independent Lines:** Calculate four separate moving averages based on a single higher timeframe.
* **Full Customization:** Each line has its own Period and MA Type (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA).
* **Dynamic Data Window:** The indicator automatically updates the Data Window labels (e.g., showing "EMA(8)" instead of "MA 1") to reflect your current settings, making analysis easier.
* **Heikin Ashi Support:** Can calculate the ribbon based on Heikin Ashi price levels.

## 3. MQL5 Implementation Details

* **Modular Architecture:** The indicator uses a "Manager" class (`MovingAverage_Ribbon_MTF_Calculator.mqh`) that controls four independent instances of a helper calculator. This allows for mixing different MA types within the same ribbon.

* **Optimized Incremental Calculation:**
    Despite calculating 4 lines on a higher timeframe, the indicator remains extremely fast:
  * **State Tracking:** Each of the 4 lines tracks its own calculation state on the higher timeframe.
  * **Persistent Buffers:** Recursive states are preserved, ensuring O(1) complexity per tick.
  * **Efficient Mapping:** The projection logic is optimized to minimize array operations.

## 4. Parameters

### Timeframe & Price

* **`InpUpperTimeframe`:** The single higher timeframe for the entire ribbon.
* **`InpSourcePrice`:** The source price (Standard or Heikin Ashi).

### Line Settings (MA 1 - MA 4)

* **`InpPeriod`:** Lookback period.
* **`InpMAType`:** The algorithm to use (SMA, EMA, etc.).

## 5. Usage and Interpretation

* **Ribbon Expansion:** When the lines fan out (expand) and slope in the same direction, the higher timeframe trend is strengthening.
* **Ribbon Contraction/Twist:** When the lines converge or cross over each other, the higher timeframe is consolidating or reversing.
* **Dynamic Zones:** The area between the fast and slow lines of the MTF ribbon acts as a powerful support/resistance zone during pullbacks.
