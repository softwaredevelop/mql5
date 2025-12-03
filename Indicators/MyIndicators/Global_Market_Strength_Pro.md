# Global Market Strength Pro

## 1. Summary (Introduction)

The `Global_Market_Strength_Pro` is a universal relative strength analyzer designed for "Global Macro" trading. Unlike currency strength meters that are limited to Forex, this indicator allows you to compare the performance of **any 8 symbols** available on your platform (Indices, Commodities, Crypto, Stocks, Forex) in a single window.

Its primary purpose is to visualize the flow of capital between different asset classes and regions. It answers critical questions like:

* "Is money flowing into Tech (Nasdaq) or Industry (Dow)?"
* "Is the market in 'Risk On' (Stocks up) or 'Risk Off' (Gold up) mode?"
* "Which region is outperforming: USA, Europe, or Asia?"

## 2. Mathematical Foundations and Calculation Logic

The indicator uses a standardized **Rate of Change (ROC)** calculation to make different assets comparable.

### Calculation Steps

1. **Data Collection:** The indicator retrieves the closing prices for up to 8 user-defined symbols.
2. **ROC Calculation:** For each symbol, it calculates the percentage change over the user-defined `Period`.
    * $\text{ROC} = \frac{\text{Close}_t - \text{Close}_{t-n}}{\text{Close}_{t-n}} \times 100$
3. **Smoothing (Optional):** The raw ROC values can be smoothed using a Moving Average to filter out noise and reveal the underlying trend.

By using percentage change, the indicator allows for a direct "apples-to-apples" comparison between assets with vastly different prices (e.g., Bitcoin at 90,000 vs. EURUSD at 1.05).

## 3. MQL5 Implementation Details

* **Universal Engine (`Symbol_Strength_Calculator.mqh`):** The core logic is encapsulated in a flexible engine that can handle any symbol string provided by the user. It includes robust error handling for missing data or synchronization delays, ensuring the indicator doesn't freeze the terminal while waiting for data.
* **Robust Data Handling:** The indicator includes advanced synchronization checks (`IsDataReady`). It ensures that historical data for all selected symbols is fully loaded and synchronized before performing calculations. This prevents the display of misleading or "glitchy" lines during chart startup or timeframe changes.
* **Safe Smoothing Algorithm:** The smoothing logic is designed to handle data gaps and initialization phases gracefully, preventing mathematical overflows or "exploding" values that can occur when smoothing incomplete data series.
* **Dynamic Dashboard:** A custom-drawn dashboard panel in the indicator window provides a real-time, sorted list of the active symbols with their exact strength values (to 3 decimal places), color-coded to match the chart lines. It automatically hides symbols that are disabled in the settings.

## 4. Parameters

* **`InpPeriod`:** The lookback period for the ROC calculation. Default is `14`.
* **`InpTimeframe`:** The timeframe used for the calculation.
* **`InpSmooth`:** Enables smoothing of the strength lines. Default is `true`.
* **`InpSmoothPer`:** The period for the smoothing. Default is `5`.
* **Symbols & Colors:**
  * **`InpSymbol1` - `InpSymbol8`:** The names of the symbols to analyze (e.g., "US500", "Gold", "BTCUSD"). Leave empty to disable a slot.
  * **`InpShow1` - `InpShow8`:** Toggles the visibility of each symbol's line and label.
  * **`InpColor1` - `InpColor8`:** The color for each symbol's line and label.

## 5. Usage and Interpretation

This indicator is the "Strategic Compass" for multi-asset traders.

### Core Strategies

1. **Risk On / Risk Off:**
    * **Risk On:** Equity indices (US500, USTEC, DE40) are rising and are at the top of the matrix. Safe havens (Gold, JPY) are falling or at the bottom.
    * **Risk Off:** Equities are falling. Safe havens (Gold, JPY) are rising and leading the matrix.
    * *Action:* If Gold spikes while Stocks drop, look for short setups on indices.

2. **Sector Rotation (US Indices):**
    * Compare **USTEC (Nasdaq)** vs. **US30 (Dow)**.
    * If USTEC > US30: Growth/Tech stocks are leading.
    * If US30 > USTEC: Value/Industrial stocks are leading.

3. **Regional Rotation:**
    * Compare **US500 (USA)** vs. **DE40 (Europe)** vs. **JP225 (Asia)**.
    * Trade the index of the strongest region against the weakest region (if your broker allows) or simply focus your intraday trading on the strongest market.

4. **Commodity Correlations:**
    * Rising **Oil (WTI)** often supports energy-heavy indices (like UK100) but can weigh on consumer/tech sectors due to inflation fears.

## 6. Troubleshooting

If a line appears flat at 0.000% or shows "N/A":

1. **Check Symbol Name:** Ensure the symbol name entered in the parameters matches **exactly** what is listed in your Market Watch window (e.g., your broker might use "XAUUSD" instead of "Gold", or "SPX500" instead of "US500").
2. **Check Experts Tab:** Look at the "Experts" tab in the Terminal toolbox. The indicator will print an error message if it cannot find a symbol (e.g., `Symbol 'Gold' not found!`).
3. **Data Loading:** On the first load, it might take a few seconds for the indicator to download history for all symbols.
