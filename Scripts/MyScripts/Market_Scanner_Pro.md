# Market Scanner Pro (Script)

## 1. Summary (Introduction)

The `Market_Scanner_Pro` is a high-performance quantitative analysis tool designed to bridge the gap between technical charting and AI-assisted trading. It is an "Institutional Market X-Ray" that performs a multi-timeframe, multi-indicator scan across a portfolio of assets and exports the market state into a structured CSV format.

This dataset ("QuantScan 3.0") is optimized for Large Language Models (LLMs) or statistical analysis tools. Instead of raw price data, it provides normalized scores (Z-Score, Efficiency Ratio, Relative Strength), offering deep insights into Trend Quality, Institutional Footprints, and Statistical Reversion risks.

## 2. Methodology and Logic

The script employs a **Hybrid Analysis Model** with three core layers:

1. **Context Layer (H1):** Determines the "Big Picture". It identifies the dominant trend direction, the structural quality of that trend, and correlation with the broader market (Relative Strength).
2. **Trigger Layer (M15):** Analyzes "Execution Timing". It monitors momentum shifts, volatility regimes, and statistical extremes.
3. **Institutional Layer (New):** Detects hidden market mechanics, specifically "Absorption" (high volume vs. low range) and extreme probability of mean reversion.

### Key Metrics Defined

* **Trend Score (Z-Score & Deviation):** Measures how far the price is from the trend baseline in units of volatility (ATR).
* **Relative Strength (RS):** Compares the asset's performance against a Benchmark (e.g., US500) over the last 24 hours. A positive RS indicates the asset is outperforming the market.
* **Institutional Absorption:** A logical check based on Wyckoff principles. If Volume is extreme (RVOL > 2.0) but Price Movement is small, it indicates passive limit orders absorbing aggressive market orders—often a sign of a reversal.
* **Reversion Probability:** A composite score (0-100%) that combines Z-Score extremes, Murrey Levels, and Momentum Exhaustion to predict a potential pullback.

## 3. MQL5 Implementation Details

The script is built upon the **"Professional Indicator Suite"** architecture, ensuring mathematical precision and performance.

* **Calculation Engines (`.mqh`):** It directly instantiates optimized Calculation Classes (e.g., `CDSMACalculator`, `CVWAPCalculator`) rather than using slow `iCustom` calls.
* **Defensive Programming:** Includes rigorous safety checks (e.g., array bounds checking in ATR) to prevent runtime crashes during large-scale scanning.
* **Smart Data Fetching:** Utilizes efficient `FetchData` wrappers to retrieve and sync OHLCV data for multiple timeframes instantaneously.

## 4. Parameters

* **Scanner Config:**
  * `InpUseMarketWatch`: If `true`, scans all active symbols.
  * `InpSymbolList`: Custom symbol list (if using manual selection).
  * `InpBenchmark`: The symbol for Relative Strength comparison (Default: `US500`).
  * **`InpBrokerTimeZone`**: **NEW!** Your broker's timezone name (e.g. `EET`, `UTC+3`). This string is added to the CSV header so the AI knows the context of the timestamp (crucial for detecting Session Opens/Closes).
  * **`InpScanHistory`**: **NEW!** Number of bars to download for analysis (Default: `500`). Increase this if using slow moving averages (200 SMA).
* **Timeframes:**
  * `InpTFFast` (Trigger): Default `M15`.
  * `InpTFSlow` (Context): Default `H1`.
  * **Metric Settings:**
  * **`InpRSBars`**: **NEW!** Lookback period for Relative Strength calculation.
    * `24 (Default on H1)` = 24 Hours performance.
    * `120` = Weekly performance.
  * Indicators fine-tuning (DSMA, Gamma, etc).
* **Squeeze Settings:**
  * Allows fine-tuning of the Volatility Squeeze sensitivity (`BB Multiplier`, `KC Multiplier`).
* **TSI Settings:**
  * Customizable periods for the True Strength Index (Cycle).

## 5. Output Data Structure (CSV - QuantScan 3.0)

The script generates a file named `QuantScan_YYYY.MM.DD_HHMM.csv` in the `MQL5\Files` folder.

| Header | Description | Interpretation / ranges |
| :--- | :--- | :--- |
| **`TIME`** | Timestamp | `YYYY.MM.DD HH:MM` format. |
| **`SYMBOL`** | Asset Name | e.g., `EURUSD`. |
| **`PRICE`** | Current Bid | The snapshot price at scan time. |
| **`TREND_SCORE`** | **H1 Trend Strength** | Normalized deviation. <br>• `> +1.0`: Strong Bull<br>• `< -1.0`: Strong Bear |
| **`TREND_QUAL`** | **H1 Efficiency** | Trend noise filter (Kaufman ER). <br>• `> 0.6`: Clean Trend (Safe to trade) |
| **`ZONE`** | **H1 Structure** | Murrey Math Level. <br>• `Extreme`: Reversal zone.<br>• `Range`: Trading zone. |
| **`REL_STRENGTH`** | **Relative Perf.** | Performance vs Benchmark (24h). <br>• `> 0%`: Leader (Stronger than market)<br>• `< 0%`: Laggard (Weaker than market) |
| **`MOMENTUM`** | **M15 Laguerre** | Fast momentum (0.0 - 1.0). <br>• `> 0.85`: Bullish Pressure (Gamma lag) |
| **`VOL_QUAL`** | **M15 RVOL** | Relative Volume. <br>• `> 1.5`: High Activity<br>• `< 0.7`: Low Low Interest |
| **`SQUEEZE`** | **M15 Vola State** | TTM Squeeze status. <br>• `ON`: Energy building (Prepare for breakout). |
| **`Z_SCORE`** | **M15 Statistics** | Standard Deviations from mean. <br>• `> 2.5`: Statistically Extreme. |
| **`VOL_REGIME`** | **M15 Vola Trend** | Ratio of Short/Long ATR. <br>• `> 1.0`: Volatility is expanding. |
| **`TSI_DIR`** | **M15 Cycle** | Cycle direction (`BULL` / `BEAR`). |
| **`REVERSION_PROB`** | **Reversion %** | Composite probability of a pullback. <br>• `> 80%`: High risk of reversal. |
| **`ABSORPTION`** | **Inst. Volume** | Wyckoff Absorption signal. <br>• `YES`: High Vol + Small Body (Hidden activity). |

## 6. Usage Workflow

1. **Run the Script:** Drag `Market_Scanner_Pro` onto any chart.
2. **Wait for Completion:** Check the "Experts" tab.
3. **Locate File:** Open "File -> Open Data Folder -> MQL5 -> Files".
4. **Process with AI:** Upload the `QuantScan_....csv` file to your LLM with a prompt like:

    > *"Analyze this market data. Look for two specific setups:*
    >
    > 1. ***The Whale Utility:** Strong Trend (`TREND_SCORE > 0.5`) + Strong Relative Strength (`REL_STRENGTH > 0`) + Squeeze is `ON`.
    > 2. ***The Reversion Trap:** High Reversion Probability (`> 80%`) AND Absorption is `YES`.
    >
    > *List the top 3 candidates for each."*
