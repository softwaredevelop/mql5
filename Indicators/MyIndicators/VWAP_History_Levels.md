# VWAP History Levels (Indicator)

## 1. Summary

**VWAP History Levels** is an institutional Support and Resistance (S/R) indicator. Instead of plotting dynamic, moving lines, it captures the **exact closing value of the VWAP** at the end of a specific period (Day, Week, Month) and projects it forward as a static horizontal ray.

In quantitative and institutional trading, this concept is known as **Institutional Memory** or **Naked/Virgin VWAP**. Large algorithmic execution engines "remember" where the true average value of the previous periods settled. These historical closing VWAPs act as massive gravitational magnets or concrete walls for future price action.

## 2. Methodology & Logic

The indicator runs three separate VWAP engines internally (Daily, Weekly, Monthly). At the exact moment a period closes (e.g., midnight for the Daily session), the indicator records the final VWAP value.

* **The Projection:** It then draws a horizontal ray (`OBJ_TREND`) starting from the close of that period, projecting into the future.
* **The Concept:** If the current price is above last week's VWAP close, the overall macro momentum is bullish, and that weekly line will serve as primary institutional support upon retests.

## 3. MQL5 Implementation Details

* **Smart Object Management (Garbage Collection):** Drawing hundreds of historical lines clutters the chart and drains CPU. This indicator features an internal garbage collection algorithm (`CleanOldObjects`). If you set it to keep only the last 3 days, it will automatically delete the 4th oldest line and its text label, keeping your workspace perfectly clean.
* **Deep History Optimization:** To prevent terminal freezing on low timeframes (e.g., M1 or M5), the indicator restricts deep historical VWAP calculation to a safe limit (5,000 bars for Daily/Weekly, 40,000 bars for Monthly).
* **Bufferless Architecture:** It does not consume MQL5 drawing buffers. Everything is rendered via native MT5 objects with clean text anchors (`OBJ_TEXT`).

## 4. Parameters

* **Daily Levels (`InpShowDaily`):** Toggle daily VWAP closes.
  * `InpDailyCount` (Default: `3`): Number of previous days to keep on the chart.
  * `InpDailyColor` (Default: `DeepPink`): Visual identifier.
* **Weekly Levels (`InpShowWeekly`):** Toggle weekly VWAP closes.
  * `InpWeeklyCount` (Default: `3`): Keeps the last 3 weeks.
  * `InpWeeklyColor` (Default: `DodgerBlue`): Visual identifier.
* **Monthly Levels (`InpShowMonthly`):** Toggle monthly VWAP closes.
  * `InpMonthlyCount` (Default: `2`): Keeps the current and previous month's baseline.
  * `InpMonthlyColor` (Default: `MediumTurquoise`): Visual identifier.

## 5. Strategic Usage

1. **The "Magnet" Effect:**
   If the price breaks out of a consolidation zone, the most highly probable target for algorithmic take-profits is the nearest uncovered (untested) Historical VWAP line.
2. **Support/Resistance Confluence:**
   When a Historical VWAP level precisely aligns with a Murrey Math Line (`Murrey_Math_Line_X`) or the lower boundary of the `VScore_Bands_Pro`, you have a Tier-1 institutional reversal zone. Buy Limit or Sell Limit orders placed at these specific intersections carry an extremely high Win Rate.
3. **Trend Bias Confirmation:**
   * **Bullish Regime:** Price is trading *above* the Daily VWAP, which is *above* the Weekly VWAP.
   * **Bearish Regime:** Price is trading *below* the Daily VWAP, which is *below* the Weekly VWAP.
   * Do not take short trades into a Weekly VWAP line from above; it acts as institutional concrete.
