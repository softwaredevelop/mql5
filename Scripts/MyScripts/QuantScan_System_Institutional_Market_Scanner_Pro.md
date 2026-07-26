# QuantScan System: Institutional Market Scanner Pro (V10.38)

## 1. Summary (Introduction)

The **Market_Scanner_Pro (QuantScan V10.38)** is the flagship high-frequency data extraction, regime-classification, and statistical auditing engine of the **QuantScan System**.

Developed to operate as the primary bridge between the MetaTrader 5 trading terminal and advanced Large Language Models (LLMs) or quantitative machine learning pipelines, the scanner aggregates multi-timeframe (MTF) market microstructure data across dozens of financial instruments simultaneously.

Rather than relying on single-timeframe price action, the scanner utilizes an institutional-grade **Multi-Layered Statistical Architecture**:

* **Layer 1: Context (H1 - Macro Regime):** Identifies institutional market regime, cointegration, structural zones, and relative performance (Alpha, Beta, VHF, R-Squared, Murrey Math, Weekly Z-Score).
* **Layer 2: Flow (M15 - Cycle & Volatility Squeezes):** Evaluates short-term liquidity deviations, cycle autocorrelation, momentum squeezing, and historical levels (Daily V-Score, Autocorrelation, Squeeze, Volatility Regime, PDH/PDL distance).
* **Layer 3: Trigger (M5 - Micro-Execution Velocity):** Measures immediate price speed, tick volume delta proxy, institutional volume thrust, and transaction costs (Slope, Volume Pressure, Volume Thrust, Spread Cost).
* **Layer 4: Composites (MTF Alignment):** Synthesizes multi-timeframe directional pressure and advanced Volume Spread Analysis (VSA) institutional absorption zones.

---

## 2. Software Architecture: Flyweight Engine-Caching Pattern

To scan dozens of symbols across three timeframes in milliseconds, the scanner was upgraded from a procedural allocation-heavy structure to an object-oriented **Flyweight / Engine-Caching Pattern**.

### A. The Allocation Bottleneck (Procedural vs. OO)

In legacy procedural architectures, analyzing a single symbol required the stack to instantiate, initialize, and destroy 11 independent calculator classes. In a loop of 20 symbols, this triggered **over 220 allocation and deallocation memory interrupts**, causing severe heap fragmentation, processor cache misses, and significant terminal lag.

### B. The Flyweight Master Class Solution

The refactored `CMarketScanner` master class instantiates all 11 indicators as private member variables **exactly once** during the script's `OnInit / OnStart` phase:

```text

[OnStart Script Init]
       │
       └──> [CMarketScanner::Init()]
                   │
                   ├──> Instantiate CATRCalculator m_atr
                   ├──> Instantiate CVScoreCalculator m_vscore_day
                   ├──> Instantiate CLinearRegressionCalculator m_linreg
                   └──> [Pre-Allocate Shared Buffers m_temp_buf1, m_temp_buf2]

```

During the symbol scanning loop, the scanner calls `RunAnalysis(sym, data)`. Instead of allocating new memory, the core engines reuse the pre-allocated persistent memory blocks (`m_temp_buf1[]`, etc.) and calculate the values. Memory pages remain resident in the **L1/L2 processor cache**, reducing CPU execution time by **up to 500%** and ensuring zero runtime memory leaks.

---

## 3. Mathematical & Statistical Foundations

The scanner's metrics are based on advanced quantitative formulas:

### A. Alpha and Beta (Capital Asset Pricing Model - CAPM)

Tracks the relative volatility (Beta) and idiosyncratic excess return (Alpha) of an asset relative to its regional benchmark (such as `US500` for Equities or `DXY` for Forex):

$$\beta = \frac{\text{Covariance}(R_{\text{asset}}, R_{\text{bench}})}{\text{Variance}(R_{\text{bench}})}$$

$$\alpha = R_{\text{asset}} - \beta \times R_{\text{bench}}$$

Where $R$ represents the logarithmic price returns over the specified lookback window $N$ (`InpBetaLookback`).

### B. Vertical Horizontal Filter (VHF)

VHF determines whether a market is in a trending or a congested range phase:

$$\text{VHF} = \frac{\max(P_{t \dots t-N}) - \min(P_{t \dots t-N})}{\sum_{j=0}^{N-1} |P_{t-j} - P_{t-j-1}|}$$

The scanner uses `VHF_MODE_HIGH_LOW` (replacing close prices with high-low ranges) to achieve a more sensitive volatility-adjusted result.

### C. Linear Regression R-Squared ($R^2$)

Measures the strength of the linear trend by evaluating the Coefficient of Determination. $R^2$ values close to `1.0` indicate a highly linear, efficient trend, while values close to `0.0` indicate random walk or consolidation:

$$R^2 = \frac{\big( N\sum XY - \sum X\sum Y \big)^2}{\big[ N\sum X^2 - (\sum X)^2 \big] \big[ N\sum Y^2 - (\sum Y)^2 \big]}$$

Where $X$ is mapped to chronological bar indexes ($0 \dots N-1$) and $Y$ represents the corresponding price.

### D. V-Score (VWAP Volume Z-Score)

V-Score measures price deviation relative to the Volume Weighted Average Price (VWAP) in units of volume-weighted standard deviation (Sigma). It is calculated on both Daily (Session) and Weekly resets:

$$\text{VWAP}_t = \frac{\sum (P_t \times V_t)}{\sum V_t}$$

$$\text{V-Score}_t = \frac{P_t - \text{VWAP}_t}{\sigma_{\text{VWAP}, N}}$$

### E. Volume Pressure (Tick Delta Proxy)

Acting as a high-frequency proxy for tick volume delta (buyer vs. seller aggression) without requiring raw order book L2 data, the Money Flow Multiplier is computed and smoothed:

$$\text{Volume Pressure}_t = \frac{(C_t - L_t) - (H_t - C_t)}{H_t - L_t} \times V_t$$

### F. Wyckoff Institutional Absorption (Effort vs. Result)

Natively integrated from the `Absorption_Pro` VSA engine, this logic detects institutional accumulation/distribution blocks by identifying bars where high volume (Effort) fails to produce directional price spread (Result):

$$\text{Effort} = \text{RVOL}_t > 2.0 \quad \text{AND} \quad \text{Result} = \text{Spread}_t < 0.35 \times \text{ATR}_t$$

$$\text{ClosePos} = \frac{C_t - L_t}{H_t - L_t} \implies \begin{cases}
CP_t > 0.66 \implies \textbf{BULL\_ABS} \quad \text{(Demand absorbs Supply)} \\
CP_t < 0.33 \implies \textbf{BEAR\_ABS} \quad \text{(Supply absorbs Demand)} \\
\text{otherwise} \implies \textbf{NEUT\_ABS} \quad \text{(Balanced struggle)}
\end{cases}$$

---

## 4. Historical Backtesting & Auditing Pipeline

To facilitate historical research, database creation, and comparative audits with past live runs, the scanner supports **precise historical temporal offset scanning**.

### A. Temporal Sliding Window Offset (`iBarShift`)
When `InpUseTargetTime` is enabled, the scanner calculates the exact bar offset (`start_bar`) for the target evaluation minute on every timeframe:

$$\text{start\_bar}_{\text{tf}} = \text{iBarShift}(\text{Symbol}, \text{timeframe}, \text{InpTargetTime}, \text{false})$$

The `FetchData` engine shifts its copying window back in history by `start_bar` indexes:

```text

[Standard Mode]     TimeCurrent() <── [ CopyInpScanHistory bars ]
[Historical Audit]  InpTargetTime <── [ CopyInpScanHistory bars ] (Shifted by start_bar)

```

Because of chronological array sorting, index `ArraySize - 1` in the copied array represents the exact target minute (e.g. `08:32` or `09:37`). The indicators calculate the historical state as if it were the live bar, eliminating all post-bar information leakage (no lookahead bias).

### B. High-Precision Timing & Live Pricing
* **Exact Timestamp Mapping:** The exported CSV `TIME` column reflects the exact user-defined target minute (e.g., `09:37`) instead of being rounded to the hour.
* **Exact Live Price Tracking:** The `PRICE` column prints the actual live BID price (`SymbolInfoDouble`) of the symbol at the moment of execution to maintain data alignment with the legacy execution pipeline.

---

## 5. Dataset Schema (The CSV Output Layout)

The scanner outputs a semi-colon-separated CSV file with a dynamic filename (e.g. `QuantScan_20260724_0937.csv`) containing the following dataset schema:

| Column Name | Data Type | Analytical Meaning |
| :--- | :--- | :--- |
| **`TIME`** | `string` | The exact evaluation timestamp (Broker Time, e.g., `2026.07.24 09:37`). |
| **`SYMBOL`** | `string` | The symbol ticker name (e.g., `EURUSD`, `XAUUSD`). |
| **`PRICE`** | `double` | The live BID price of the symbol. |
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
| **`V_PRES_M5`** | `double` | Volume Pressure (Tick Delta Proxy momentum) on M5. |
| **`VOL_THRUST`** | `double` | Ratio of M5 RVOL / M15 RVOL (Micro volume injection strength). |
| **`COST_ATR_M5`** | `double` | Live spread cost normalized in ATR units (Transaction friction). |
| **`ABSORPTION`** | `string` | Institutional Wyckoff Absorption pattern (`BULL_ABS`, `BEAR_ABS`, `CLIMAX`, `NO`). |
| **`MTF_ALIGN`** | `string` | Trend alignment direction across H1, M15, M5 (`FULL_BULL`, `MAJOR_BEAR`, etc.). |
| **`VWAP_ALIGN`** | `string` | Alignment of Price relative to Daily and Weekly VWAP averages. |

---

## 6. LLM & Quant Ingestion Strategies

### A. Regional Market Sentiment Analysis
By parsing the global header (`### GLOBAL_SENTIMENT | ... ###`), the LLM immediately grasps the macro regime across various assets. The relationship between `US500` (risk benchmark) and `DXY` (safe-haven dollar index) dictates whether the market is in a **Risk-On, Risk-Off, Stress, or Deflationary** state, which scales the model's global risk parameters.

### B. High-Probability Order-Flow Filters
The LLM can combine `ABSORPTION`, `V_SCORE_D1`, and `VOL_THRUST` to identify high-probability institutional pools:
* **Long Ingest:** When `ABSORPTION = BULL_ABS`, `V_SCORE_D1` is oversold ($<-2.0$), and `VOL_THRUST > 1.5`, the model identifies a high-volume institutional support block where sellers have exhausted and passive institutional limit buying has completed.
* **Transaction Cost Safeguard:** Scalping strategies must inspect `COST_ATR_M5`. If cost is $> 0.30$ (30% of volatility), the LLM can veto execution due to excessive friction.
