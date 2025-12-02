# Currency Strength Pro

## 1. Summary (Introduction)

The `Currency_Strength_Pro` is a fundamental tool for Forex portfolio selection. Unlike standard indicators that analyze a single chart, this "dashboard indicator" monitors the entire market simultaneously. It calculates and displays the relative strength of the 8 major currencies (USD, EUR, GBP, JPY, AUD, CAD, CHF, NZD) by analyzing price movements across all 28 major currency pairs.

Its primary purpose is to answer the question: **"Which currency is currently the strongest, and which is the weakest?"**

By identifying these outliers, traders can pair the strongest currency against the weakest one to find the highest-probability trading setups with the strongest momentum.

## 2. Mathematical Foundations and Calculation Logic

The indicator uses a Rate of Change (ROC) based algorithm to score each currency.

### Calculation Steps

1. **Data Collection:** The indicator retrieves the closing prices for all 28 major currency pairs (e.g., EURUSD, GBPJPY, AUDCAD, etc.).
2. **ROC Calculation:** For each pair, it calculates the percentage change over the user-defined `Period`.
3. **Score Aggregation:**
    * If a pair (e.g., EURUSD) rises, the Base currency (EUR) gains points, and the Quote currency (USD) loses points.
    * If a pair falls, the Base currency loses points, and the Quote currency gains points.
    * This process is repeated for all 28 pairs, summing up the scores for each individual currency.
4. **Smoothing (Optional):** The raw scores can be smoothed using a Moving Average (SMA/EMA) to filter out short-term noise and reveal the underlying trend of strength.

## 3. MQL5 Implementation Details

* **Multi-Symbol Engine (`Currency_Strength_Calculator.mqh`):** The core logic is encapsulated in a robust engine that handles the complexity of accessing data from 28 different symbols simultaneously.
* **Robust Data Handling:** The indicator includes advanced synchronization checks (`IsDataReady`). It ensures that historical data for all 28 pairs is fully loaded and synchronized before performing calculations. This prevents the display of misleading or "glitchy" lines during chart startup or timeframe changes.
* **Optimized Performance:** To prevent freezing the terminal, the indicator limits the history calculation on the first load. Subsequent updates are incremental and extremely fast.
* **Interactive Dashboard:** A custom-drawn dashboard panel in the indicator window provides a real-time, sorted list of currencies with their exact strength values (to 3 decimal places). It gracefully handles missing data by displaying "N/A" instead of erroneous values.

## 4. Parameters

* **`InpPeriod`:** The lookback period for the ROC calculation. Default is `14`.
  * Lower values (e.g., 5-10) make the indicator more sensitive to recent news.
  * Higher values (e.g., 20-50) show the longer-term trend strength.
* **`InpTimeframe`:** The timeframe used for the calculation. Usually set to `PERIOD_CURRENT`, but can be fixed to a higher timeframe (e.g., H1) for multi-timeframe analysis.
* **`InpSmooth`:** Enables smoothing of the strength lines. Default is `true`.
* **`InpSmoothPer`:** The period for the smoothing. Default is `5`.
* **`InpShowPanel`:** Toggles the visibility of the dashboard panel.

## 5. Usage and Interpretation

This indicator is a **strategic filter**. It tells you *what* to trade, not necessarily *when* to enter.

### Core Strategies

1. **The "Crocodile Mouth" (Divergence):**
    * Look for two lines that are moving sharply away from each other.
    * **Example:** If USD (Green) is shooting up and JPY (Gold) is diving down, this indicates strong USD buying and JPY selling across the board.
    * **Action:** Look for **Long** setups on **USDJPY**.

2. **Trend Reversal (Crossover):**
    * When a currency that has been very strong starts to turn down, and a weak currency starts to turn up, a reversal may be imminent.
    * The actual crossover of the lines confirms the shift in power.

3. **The Zero Line:**
    * The 0 level represents neutrality. Currencies hovering around 0 are range-bound and lack clear direction.
    * **Breakout:** When a currency line breaks sharply away from the 0 level, it signals the start of a new momentum phase.

### Workflow: The "Session Open" Routine

The most effective way to use this indicator is during the pre-market analysis before major session opens (London or New York).

1. **Check H1/H4:** Identify the strongest and weakest currencies over the last 24 hours.
2. **Select Pairs:** Create a "Watchlist" for the day by pairing the Top 2 strongest against the Bottom 2 weakest currencies. (e.g., Strong GBP + Weak AUD -> Trade GBPAUD Long).
3. **Wait for Timing:** Switch to a lower timeframe (M5/M15) on your selected pair and use your tactical indicators (like `VWAP_Pro` or `MACD_Laguerre_Pro`) to time the entry.

### Tips

* **Avoid Correlation:** Do not trade multiple pairs that are driven by the same currency move (e.g., Long EURUSD and Long GBPUSD) unless you want to double your risk on the USD weakness.
* **News Events:** Be aware that high-impact news can cause sudden spikes in the strength lines. Wait for the lines to stabilize after news before entering.
