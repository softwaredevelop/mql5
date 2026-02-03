# Market Scanner Pro (Script)

## 1. Summary (Introduction)

The `Market_Scanner_Pro` is a high-performance quantitative analysis tool designed to bridge the gap between technical charting and AI-assisted trading. It performs a multi-timeframe, multi-indicator scan across a portfolio of assets and exports the "Market State" into a structured CSV format suitable for Large Language Models (LLMs) or statistical analysis tools (Python/Excel).

Instead of relying on basic price data, this script generates **"QuantScan 2.0"** metrics: it converts raw indicator values into normalized scores (e.g., Z-Score, Efficiency Ratio), providing a deep insight into Trend Quality, Momentum, and Statistical Extremes.

## 2. Methodology and Logic

The script employs a **Hybrid Analysis Model**, splitting metrics into two logical timeframes:

1. **Context Layer (H1):** Analyzes the "Big Picture". It determines the dominant trend direction, the structural quality of that trend, and key support/resistance zones.
2. **Trigger Layer (M15):** Analyzes the "Execution Timing". It looks for momentum shifts, volume anomalies, and statistical reversion signals.

### Key Metrics Calculated

* **Trend Score (Z-Score Proxy):** Measures how far the price is from the mean (DSMA) in units of volatility (ATR). A score of +2.0 means the price is 2 standard deviations above the trend.
* **Trend Quality (Efficiency Ratio):** Differentiates between a smooth, tradeable trend (High ER) and a choppy, dangerous market (Low ER).
* **Volatility Regime (Squeeze):** Identifies periods of low volatility (Bollinger Bands inside Keltner Channels) that often precede explosive moves.
* **Volume Quality (RVOL):** Checks if the current move is supported by institutional volume (Relative Volume > 1.0).

## 3. MQL5 Implementation Details

The script is built upon the **"Professional Indicator Suite"** architecture, ensuring mathematical precision and performance.

* **Calculation Engines (`.mqh`):**
    Instead of using slow `iCustom` calls, the script directly instantiates the optimized Calculation Classes (e.g., `CDSMACalculator`, `CVWAPCalculator`) used by our indicators. This guarantees that the CSV data matches the chart visuals 100%.
* **Defensive Programming:**
    The implementation includes rigorous "Safety Checks" (e.g., array bounds checking in ATR, data availability validation) to prevent runtime crashes, even when scanning hundreds of symbols.
* **Smart Data Fetching:**
    It utilizes `FetchData` wrappers that efficiently retrieve OHLCV data and organize it into chronological arrays (`ArraySetAsSeries(false)`), optimized for our incremental calculation engines.

## 4. Parameters

* **Scanner Config:**
  * `InpUseMarketWatch`: If `true`, scans every active symbol in the Market Watch window.
  * `InpSymbolList`: A comma-separated list of symbols to scan if Market Watch is disabled (e.g., `EURUSD, BTCUSD, US500`).
* **Timeframes:**
  * `InpTFFast`: The timeframe for Trigger metrics (Default: `M15`).
  * `InpTFSlow`: The timeframe for Context metrics (Default: `H1`).
* **Metric Settings:**
  * Allows fine-tuning of indicators (e.g., `InpDSMAPeriod`, `InpLaguerreGamma`, `InpRVOLPeriod`).
* **Squeeze Settings:**
  * Controls the sensitivity of the volatility squeeze detection (`BB Multiplier`, `KC Multiplier`).

## 5. Output Data Structure (CSV)

The script generates a file named `QuantScan_YYYY.MM.DD_HHMM.csv` in the `MQL5\Files` folder.

### Columns Explanation

| Header | Description | Interpretation |
| :--- | :--- | :--- |
| **`TIME`** | Timestamp | `YYYY.MM.DD HH:MM` format. |
| **`SYMBOL`** | Asset Name | e.g. `EURUSD`. |
| **`PRICE`** | Current Bid | The snapshot price at scan time. |
| **`TREND_SCORE`** | **H1 Trend Strength** | Normalized deviation from trend. <br>• `> +1.0`: Strong Bull<br>• `< -1.0`: Strong Bear |
| **`TREND_QUAL`** | **H1 Efficiency** | Quality of the trend (Kaufman ER). <br>• `> 0.6`: Clean Trend<br>• `< 0.3`: Noise/Chop |
| **`ZONE`** | **H1 Structure** | Murrey Math Level. <br>• `Extreme`: Reversal likely.<br>• `Range`: Trading Zone. |
| **`MOMENTUM`** | **M15 Laguerre** | Fast momentum (0.0 - 1.0). <br>• `> 0.8`: Bullish Pressure<br>• `< 0.2`: Bearish Pressure |
| **`VOL_QUAL`** | **M15 RVOL** | Instant Institutional Interest. <br>• `> 1.5`: High Activity<br>• `< 0.8`: No interest |
| **`SQUEEZE`** | **M15 Vola State** | TTM Squeeze status. <br>• `ON`: Energy building (Prepare for breakout). |
| **`TSI_DIR`** | **M15 Cycle** | True Strength Index direction (`BULL` / `BEAR`). |

## 6. Usage Workflow

1. **Run the Script:** Drag `Market_Scanner_Pro` onto any chart.
2. **Wait for Completion:** Check the "Experts" tab for progress. It usually takes a few seconds to scan 20-30 symbols.
3. **Locate File:** Open "File -> Open Data Folder -> MQL5 -> Files".
4. **Process with AI:** Upload the `QuantScan_....csv` file to your LLM (GPT-4 / Claude 3) with a prompt like:
    > *"Analyze this market data. Identify high-quality trend setups where TREND_QUANT > 0.6 and SQUEEZE is ON. Also, warn me about mean reversion risks where Z_SCORE > 2.5."*
