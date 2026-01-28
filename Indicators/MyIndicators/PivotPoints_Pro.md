# Pivot Points Pro

## 1. Summary (Introduction)

**Pivot Points Pro** is a professional-grade support and resistance indicator designed for precision trading. Unlike standard pivot indicators that clutter the chart with historical lines, this tool focuses on clarity and relevance by displaying levels **only for the current period**.

It offers advanced features such as:

* **Multi-Timeframe (MTF) Calculation:** Display Daily pivots on an M15 chart, Weekly pivots on H1, etc.
* **5 Calculation Modes:** Classic, Fibonacci, Woodie, Camarilla, and DeMark.
* **Heikin Ashi Support:** Calculate pivot levels based on Heikin Ashi candles for smoother, trend-aligned levels.
* **Full Visual Customization:** Control the color, style, and width of every level group (PP, Resistance, Support, Medians).

## 2. Mathematical Foundations

Pivot Points are calculated based on the High (H), Low (L), and Close (C) of the **previous** period.

### Calculation Modes

1. **Classic:** The standard floor trader pivots.
    * $PP = (H + L + C) / 3$
    * $R1 = 2 \times PP - L$, $S1 = 2 \times PP - H$
2. **Fibonacci:** Uses Fibonacci ratios (0.382, 0.618, 1.0) added to/subtracted from the PP.
    * $R1 = PP + 0.382 \times (H - L)$
3. **Woodie:** Gives more weight to the Close price.
    * $PP = (H + L + 2 \times C) / 4$
4. **Camarilla:** Focuses on close-range mean reversion.
    * $R3 = C + (H - L) \times 1.1 / 4$
5. **DeMark:** Uses a conditional logic based on the relationship between Open and Close to predict the next period's range.

## 3. MQL5 Implementation Details

* **Optimized Performance:** The indicator uses an intelligent caching mechanism. It calculates the levels only once per higher-timeframe period (e.g., once a day for D1 pivots), ensuring zero impact on terminal performance.
* **Current Period Only:** The indicator automatically detects the start of the current period and draws lines only from that point forward. This keeps the chart clean and focused on the "now."
* **Modular Engine:** Powered by `PivotPoint_Calculator.mqh`.

## 4. Parameters

### Timeframe Settings

* **Pivot Timeframe:** The higher timeframe used for calculation (e.g., D1, W1, MN1). Must be greater than or equal to the chart timeframe.

### Calculation Settings

* **Pivot Formula:** Select the calculation method (Classic, Fibonacci, etc.).
* **Price Source:** Select `Standard` (OHLC) or `Heikin Ashi` (HA-OHLC). Using HA can filter out noise spikes from the calculation.

### Visual Settings

* **Colors/Styles:** Customize the appearance of the Pivot Point (PP), Resistance levels (R1-R3), Support levels (S1-S3), and Median levels (M).
* **Show Medians:** Toggle the display of mid-point levels (e.g., between PP and R1).
* **Labels:** Toggle text labels and adjust their position/size.

## 5. Usage and Interpretation

### Trend Determination

* **Above PP:** If price is trading above the central Pivot Point (Gold line), the bias is **Bullish**.
* **Below PP:** If price is trading below the central Pivot Point, the bias is **Bearish**.

### Support and Resistance

* **R1, R2, R3:** Act as profit targets for long positions or potential reversal zones for short entries.
* **S1, S2, S3:** Act as profit targets for short positions or potential reversal zones for long entries.

### Breakout vs. Bounce

* **Bounce:** In a ranging market, look for price to reject these levels (e.g., buy at S1, sell at R1).
* **Breakout:** In a trending market, a strong close beyond a level (e.g., R1) often signals a continuation to the next level (R2).
