# QuantScan System: Market Scanner Pro Script (V10.39)

## Technical Specification & Integration Manual

## 1. Summary (Introduction)

The **Market_Scanner_Pro (QuantScan V10.39)** is the primary quantitative data-mining, feature-extraction, and statistical auditing engine of the **QuantScan System**. Operating as an execution script, its primary mission is to scan a multi-asset portfolio, perform multi-timeframe (MTF) mathematical calculations in milliseconds, and export a clean, normalized, and synchronized dataset (`.csv`) tailored for ingestion by Large Language Models (LLMs) or systematic machine learning models.

The scanner analyzes markets across three synchronized operational layers, providing the LLM with a complete picture of market microstructure:

* **Layer 1: Context (H1 - Macro Regime):** Evaluates CAPM Alpha/Beta, trend efficiency (VHF), trend linearity ($R^2$), Murrey Math structural zones, and Weekly VWAP Z-Scores.
* **Layer 2: Flow (M15 - Cyclical Momentum):** Tracks daily VWAP Z-Scores, lag-1 autocorrelation, volatility compression (Squeeze), volatility regimes, and previous day's extreme boundaries.
* **Layer 3: Trigger (M5 - Micro-Execution Velocity):** Measures immediate price displacement speed, money flow volume pressure, volume thrust, and live spread transaction costs.
* **Layer 4: Composites (Microstructure Alignment):** Synthesizes multi-timeframe trend alignment and advanced Wyckoff Volume Spread Analysis (VSA) institutional absorption patterns.

---

## 2. High-Performance Architecture: Flyweight Object-Caching

To process dozens of symbols across three timeframes without lagging the trading terminal, the scanner is built upon the **Flyweight Pattern / Object-Caching** software architecture.

In legacy scanner scripts, analyzing each symbol required the stack to repeatedly allocate, initialize, and destroy 11 independent calculator classes in a loop. For a 20-symbol scan, this triggered **over 220 allocation and deallocation memory interrupts**, causing severe heap fragmentation, processor cache misses, and significant execution lag.

The refactored `CMarketScanner` master class resolves this bottleneck by instantiating and initializing all 11 indicators as private member variables **exactly once** during the script's `OnInit` phase:

```text

[OnStart Script Start]
       │
       └──> [CMarketScanner::Init()]
                   │
                   ├──> Instantiate CATRCalculator m_atr
                   ├──> Instantiate CRelativeVolumeCalculator m_rvol
                   ├──> Instantiate CVScoreCalculator m_vscore_day
                   ├──> Instantiate CVScoreCalculator m_vscore_week
                   └──> [Pre-Allocate Shared Buffers m_temp_buf1...4]

```

During the symbol scanning loop, the script calls `RunAnalysis(sym, data)`. Instead of allocating new memory, the core engines reuse the pre-allocated persistent memory blocks (`m_temp_buf1[]`, etc.) and calculate the values. Memory pages remain resident in the **L1/L2 processor cache**, reducing CPU execution time by **up to 500%** and ensuring zero runtime memory leaks.

---

## 3. Temporal Validation & Auditing Guards

The scanner is equipped with two critical safeguards to protect the integrity of the exported datasets during historical audits or backtesting:

### A. Temporal Sliding Window Offset (`iBarShift`)

When `InpUseTargetTime` is enabled, the scanner calculates the exact bar offset (`start_bar`) for the target evaluation minute on every timeframe:

$$\text{start\_bar}_{\text{tf}} = \text{iBarShift}(\text{Symbol}, \text{timeframe}, \text{InpTargetTime}, \text{false})$$

The `FetchData` engine shifts its copying window back in history by `start_bar` indexes. Because of chronological array sorting, index `ArraySize - 1` in the copied array represents the exact target minute (e.g. `08:32` or `09:37`). The indicators calculate the historical state as if it were the live bar, eliminating all post-bar information leakage (no lookahead bias).

### B. Strict Future-Time Validation Guard

If the user specifies a historical target time that is in the future relative to the current broker time (`InpTargetTime > TimeCurrent()`), MT5 would natively return index `0` (the active live bar) for `iBarShift`, leading to dataset corruption (saving current live data with a future timestamp).

To prevent this, the script implements a strict **Temporal Validation Guard** at the very beginning of `OnStart()`:

```mql5
if(InpUseTargetTime && InpTargetTime > TimeCurrent())
  {
   string msg = StringFormat("Critical Error: Specified Target Time (%s) is in the future!\n"
                             "Current Broker Time is %s.\n"
                             "Execution aborted to prevent dataset corruption.",
                             TimeToString(InpTargetTime), TimeToString(TimeCurrent()));

   MessageBox(msg, "QuantScan Target Time Error", MB_OK|MB_ICONERROR);
   Print("QuantScan Error: " + msg);
   return; // Abort gracefully
  }
```

If triggered, the script halts execution, logs a critical error, and displays a red error dialog popup to the user, ensuring no corrupted data enters the database.

---

## 4. Mathematical & Statistical Foundations

The scanner's metrics are based on advanced quantitative formulas:

### A. Alpha and Beta (CAPM)

Tracks the relative volatility (Beta) and idiosyncratic excess return (Alpha) of an asset relative to its regional benchmark (such as `US500` for Equities or `DXY` for Forex) over the specified lookback window $N$ (`InpBetaLookback`):

$$\beta = \frac{\text{Covariance}(R_{\text{asset}}, R_{\text{bench}})}{\text{Variance}(R_{\text{bench}})}$$

$$\alpha = R_{\text{asset}} - \beta \times R_{\text{bench}}$$

### B. Linear Regression R-Squared ($R^2$)

Measures the strength of the linear trend by evaluating the Coefficient of Determination. $R^2$ values close to `1.0` indicate a highly linear, efficient trend:

$$R^2 = \frac{\big( N\sum XY - \sum X\sum Y \big)^2}{\big[ N\sum X^2 - (\sum X)^2 \big] \big[ N\sum Y^2 - (\sum Y)^2 \big]}$$

Where $X$ is mapped to chronological bar indexes ($0 \dots N-1$) and $Y$ represents the corresponding price.

### C. V-Score (VWAP Volume Z-Score)

V-Score measures price deviation relative to the Volume Weighted Average Price (VWAP) in units of volume-weighted standard deviation (Sigma). It is calculated on both Daily (Session) and Weekly resets:

$$\text{VWAP}_t = \frac{\sum (P_t \times V_t)}{\sum V_t}$$

$$\text{V-Score}_t = \frac{P_t - \text{VWAP}_t}{\sigma_{\text{VWAP}, N}}$$

### D. Wyckoff Institutional Absorption (Effort vs. Result)

Natively integrated from the `Absorption_Pro` VSA engine, this logic detects institutional accumulation/distribution blocks by identifying bars where high volume (Effort) fails to produce directional price spread (Result):

$$\text{Effort} = \text{RVOL}_t > 2.0 \quad \text{AND} \quad \text{Result} = \text{Spread}_t < 0.35 \times \text{ATR}_t$$

$$\text{ClosePos} = \frac{C_t - L_t}{H_t - L_t} \implies \begin{cases}
CP_t > 0.66 \implies \textbf{BULL\_ABS} \quad \text{(Demand absorbs Supply)} \\
CP_t < 0.33 \implies \textbf{BEAR\_ABS} \quad \text{(Supply absorbs Demand)} \\
\text{otherwise} \implies \textbf{NEUT\_ABS} \quad \text{(Balanced struggle)}
\end{cases}$$

---

## 5. Dataset Schema (The CSV Output Layout)

The scanner outputs a semi-colon-separated CSV file with a dynamic filename (e.g. `QuantScan_20260724_0937.csv`) containing the following dataset schema:

| Column Name | Data Type | Analytical Meaning |
| :--- | :--- | :--- |
| **`TIME`** | `string` | The exact evaluation timestamp (Broker Time, e.g., `2026.07.24 09:37`). |
| **`SYMBOL`** | `string` | The symbol ticker name (e.g., `EURUSD`, `XAUUSD`). |
| **`PRICE`** | `double` | The current live BID price of the symbol (restored for consistency). |
| **`ALPHA_H1`** | `double` | CAPM Alpha relative to the benchmark (idiosyncratic excess return). |
| **`BETA_H1`** | `double` | CAPM Beta relative to the benchmark (relative market sensitivity). |
| **`VHF_H1`** | `double` | Vertical Horizontal Filter (Regime classifier: trending vs. range). |
| **`R2_H1`** | `double` | Linear Regression $R^2$ (Linear trend strength). |
| **`ZONE_H1`** | `string` | Murrey Math support/resistance zone name. |
| **`V_SCORE_W1_H1`** | `double` | Weekly VWAP Z-Score (Weekly institutional price deviation). |
| **`V_SCORE_D1_M15`**| `double` | Daily VWAP Z-Score (Daily institutional price deviation). |
| **`AUTOCORR_M15`** | `double` | Lag-1 Autocorrelation (Cycle persistence vs. mean reversion). |
| **`VOL_REGIME_M15`**| `double` | ATR(5)/ATR(55) ratio (Volatility expansion vs. compression). |
| **`SQZ_M15`** | `string` | Volatility Squeeze State (`ON` = BB inside KC, `OFF` = normal). |
| **`SQZ_MOM_M15`** | `double` | Squeeze momentum trend strength value. |
| **`VHF_M15`** | `double` | Vertical Horizontal Filter on M15. |
| **`R2_M15`** | `double` | Linear Regression $R^2$ on M15. |
| **`DIST_PDH`** | `double` | Distance of close price to Previous Day High in ATR units. |
| **`DIST_PDL`** | `double` | Distance of close price to Previous Day Low in ATR units. |
| **`VEL_M5`** | `double` | Price displacement speed in ATR units on M5. |
| **`V_PRES_M5`** | `double` | Volume Pressure (Tick Volume Delta proxy momentum) on M5. |
| **`VOL_THRUST`** | `double` | Ratio of M5 RVOL / M15 RVOL (Micro volume injection strength). |
| **`COST_ATR_M5`** | `double` | Live spread cost normalized in ATR units (Transaction friction). |
| **`ABSORPTION`** | `string` | Institutional Wyckoff Absorption pattern (`BULL_ABS`, `BEAR_ABS`, `CLIMAX`, `NO`). |
| **`MTF_ALIGN`** | `string` | Trend alignment direction across H1, M15, M5 (`FULL_BULL`, `MAJOR_BEAR`, etc.). |
| **`VWAP_ALIGN`** | `string` | Alignment of Price relative to Daily and Weekly VWAP averages. |

---

## 6. LLM & Algorithmic Ingestion Strategies

### A. Regional Market Sentiment Analysis
By parsing the global header (`### GLOBAL_SENTIMENT | ... ###`), the LLM immediately grasps the macro regime across various assets. The relationship between `US500` (risk benchmark) and `DXY` (safe-haven dollar index) dictates whether the market is in a **Risk-On, Risk-Off, Stress, or Deflationary** state, which scales the model's global risk parameters.

### B. High-Probability Order-Flow Filters
The LLM can combine `ABSORPTION`, `V_SCORE_D1`, and `VOL_THRUST` to identify high-probability institutional pools:
* **Long Ingest:** When `ABSORPTION = BULL_ABS`, `V_SCORE_D1` is oversold ($<-2.0$), and `VOL_THRUST > 1.5`, the model identifies a high-volume institutional support block where sellers have exhausted and passive institutional limit buying has completed.
* **Transaction Cost Safeguard:** Scalping strategies must inspect `COST_ATR_M5`. If cost is $> 0.30$ (30% of volatility), the LLM can veto execution due to excessive friction.
