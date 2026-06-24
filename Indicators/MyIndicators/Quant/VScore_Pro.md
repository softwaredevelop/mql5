# V-Score Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **V-Score Pro Suite** is an institutional-grade, high-performance statistical arbitrage suite comprising two advanced indicators: `VScore_Pro` (Standard) and `VScore_MTF_Pro` (Multi-Timeframe).

While standard statistical oscillators (such as the traditional Z-Score) measure price deviations from a simple, time-based simple moving average (SMA), the V-Score measures the statistical deviation from the **Volume-Weighted Average Price (VWAP)**.

$$\text{VWAP} = \frac{\sum (\text{Typical Price} \times \text{Volume})}{\sum \text{Volume}}$$

VWAP represents the "True Value"—the average price weighted by actual capital flow. Therefore, the V-Score precisely identifies whether the current price is "Expensive" or "Cheap" relative to where the major institutional money has actually been transacted, utilizing a **5-Zone Thermal Color Histogram** for zero-latency visual processing.

---

## 2. Methodology & Logic

The indicator calculates how many Standard Deviations ($\sigma$) the price has stretched away from the volume-weighted baseline.

### The Formula

$$\text{V-Score}_t = \frac{P_t - \text{VWAP}_t}{\sigma_{\text{spread}, t}}$$

* **Numerator:** The absolute distance between the current price and the dynamic VWAP.
* **Denominator:** The standard deviation of this distance over the volatility lookback window $N$ (`InpPeriod`).

### The Institutional Z-Score Levels

The indicator oscillates around **0.0** (Fair Value). Understanding the specific deviation levels is critical for interpreting market phases:

* **0.0 to $\pm$1.0 (The Noise Zone):**
  * *Meaning:* Algorithmic chop. No clear institutional directional flow.
  * *Visual:* Histogram is **Gray** (Neutral Noise).
* **$\pm$1.5 (The Point of No Return):**
  * *Meaning:* The breakout threshold. Statistically, if the price breaches and holds the 1.5 level, the momentum is strong enough that it will likely reach the 2.0 extreme.
  * *Visual:* Marked by a dashed horizontal line. Histogram shifts to **Coral** (Bull Flow) or **LightSkyBlue** (Bear Flow).
* **$\pm$1.5 to $\pm$2.0 (The Flow / Momentum Zone):**
  * *Meaning:* Active institutional accumulation or distribution. This is the optimal zone to be in a trend-following position.
* **$\pm$2.0 to $\pm$2.5 (The Extreme Zone):**
  * *Meaning:* **WARNING.** The trend is statistically overextended. The elastic band is stretched tight.
  * *Action:* Do not open new trend-following positions here.
  * *Visual:* Histogram shifts to **OrangeRed** (Bull Extreme) or **DeepSkyBlue** (Bear Extreme). Marked by solid lines.
* **$\pm$2.5 to $\pm$3.0+ (The Statistical Wall):**
  * *Meaning:* **STOP.** 99% probability of mean reversion or momentum exhaustion.
  * *Action:* Mandatory profit-taking zone. The market is at a climax. Marked by the outermost solid lines.

---

## 3. Advanced MQL5 MTF Implementation (The Warping Solution)

### A. The Live-Bar Warping Problem

In standard MTF implementations, updating the indicator separate-window tick-by-tick results in a highly distorted "jagged" or "fűrészfog" shape on the current forming HTF bar. Because standard `OnCalculate` only updates the very last lower timeframe (LTF) index (`rates_total - 1`), the previous LTF bars belonging to the active forming HTF block retain stale historic tick states.

### B. The Forming LTF Block Flat-Force Solution

`VScore_MTF_Pro` resolves this issue by implementing the **Forming LTF Block Flat-Force** step-alignment algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

By forcing a full-block rewrite on every live tick, the active HTF step (the entire colored V-Score histogram) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### C. Dynamic Volume-Type Auto-Routing Pipeline

To ensure complete robustness across all asset classes, the underlying `CVScoreCalculator` dynamically queries the broker's real volume limit (`SYMBOL_VOLUME_LIMIT`) on the chart symbol inside its `Init()` function.

* If real volume is available (e.g. Stocks, Futures, Crypto), the engine automatically initializes the VWAP calculator to use **`VOLUME_REAL`** and pull HTF real volumes (`CopyRealVolume`).
* If only tick volume is available (e.g. Forex, CFD), the engine automatically falls back to **`VOLUME_TICK`** and pull HTF tick volumes (`CopyTickVolume`).
This makes the V-Score suite completely robust, universal, and fully automated across all financial instruments.

### D. Asynchronous Timer Guard & HTF Calculations

* **Background Timer:** High-frequency MTF data requests often suffer from terminal loading gaps. A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as history is ready.
* **HTF Calculations:** On every live tick, the latest HTF price/volume elements are copied, and the VWAP and Z-Score calculators are executed incrementally, optimizing CPU cycles.

---

## 4. Solving Cumulative State Corruption in MTF VWAP

A critical, highly subtle mathematical hazard exists when calculating stateful cumulative indicators (such as VWAP) in a mocked MTF environment on live ticks.

### A. The "Double-Accumulation" Bug

If we call the calculator's `Calculate` method on every tick by passing `rates_total = g_htf_count` and `prev_calculated = rates_total - 1` (i.e. `live_idx`), the internal `CVWAPCalculator` begins its loop at index `start_index = prev_calculated - 1` (which is `rates_total - 2`, the last closed bar).
Since the loop processes `i = rates_total - 2` (which is `< rates_total - 1`), the internal state updates the persistent volume and typical price registers (`m_cumulative_vol` and `m_cumulative_tpv`).
Because this closed bar's state was *already* calculated and saved during the previous bar close, running this loop again on a live tick **double-accumulates** the closed bar's volume. On subsequent ticks, it continues to accumulate it infinitely. This drives the cumulative volume to astronomical levels, compressing the standard deviation to zero and pulling the live Z-Score to corrupted, near-zero or extreme values (as shown below).

```mql5
// CORRUPTED LIVE MOCK CALL:
g_calc.Calculate(g_htf_count, live_idx, ...); // live_idx = g_htf_count - 1
```

### B. The Resolution: MT5-Aligned State Mocking

`VScore_MTF_Pro` completely eliminates this bug by mocking the live update call exactly how the MT5 terminal's native engine handles `prev_calculated` on live ticks. We pass `prev_calculated = g_htf_count` (which equals `rates_total`):

```mql5
// FIXED LIVE MOCK CALL:
g_calc.Calculate(g_htf_count, g_htf_count, ...);
```

By passing `prev_calculated` as `g_htf_count`, the internal loop starts exactly at `start_index = g_htf_count - 1` (the live forming bar). The loop runs exactly once for the live bar, and since `i` is equal to `rates_total - 1`, the persistent registers (`m_cumulative_tpv`, `m_cumulative_vol`, etc.) are **never modified or double-accumulated**. This guarantees absolute mathematical stability and perfect alignment on every tick.

---

## 5. Parameters

### A. Common Parameters

* **Lookback Window (`InpPeriod`):** The rolling window size ($N$) for the standard deviation and volatility calculations (Default: `20` bars).
* **VWAP Reset Anchor (`InpVWAPReset`):** The reset anchor period for the underlying VWAP calculation:
  * `PERIOD_SESSION` (Default): Resets daily. Used for Intraday trading.
  * `PERIOD_WEEK`: Resets weekly. Used for Swing trading.
  * `PERIOD_MONTH`: Resets monthly. Used for Position trading.

### B. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate VWAP deviations on (Default: `PERIOD_H1`).

---

## 6. Strategic Quantitative Usage

### A. The "Point of No Return" Breakout

Wait for the V-Score to cross above **+1.5** (Coral) or below **-1.5** (LightSkyBlue) with strong price action. This confirms that the move out of the "Noise" zone is legitimate and has institutional backing.

### B. Mandatory Profit Taking (The Wall)

If you are in a Long position and the V-Score touches or exceeds **+2.5**, instantly scale out or close the position. Do not be greedy; statistical exhaustion is guaranteed.

### C. Absorption / Divergence (BULL_ABS / BEAR_ABS)

If the price makes a *New High*, but the V-Score fails to reach the Extreme Zone ($> 2.0$) and stays lower than it was at the previous price high, this is **Bull Absorption** (exhaustion of buyers). A sharp mean-reversion drop to the VWAP (0.0) is imminent.

### D. Top-Down VWAP Deviation (MTF Core Strategy)

1. **Macro Volatility Deviation (H1/H4):** Apply `VScore_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **The Setup:** Wait for the macro **H1 V-Score** to enter the **Bear Extreme Zone (DeepSkyBlue $\le -2.5$)**, indicating that the macro price is extremely cheap relative to institutional fair value.
3. **Execution:** On the lower M5 chart, only look for buy setups. Ignore all sell signals. Once the local M5 V-Score crosses back above its own **-1.5** level (or crosses its signal line), execute **BUY** orders, riding the wave of macro mean-reversion back to the macro VWAP.
