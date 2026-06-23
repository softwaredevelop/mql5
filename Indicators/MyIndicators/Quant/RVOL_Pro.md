# Relative Volume (RVOL) Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Relative Volume (RVOL) Pro Suite** is an institutional-grade volume-analysis suite comprising two advanced indicators: `RVOL_Pro` (Standard) and `RVOL_MTF_Pro` (Multi-Timeframe).

Raw volume bars can be highly misleading because transaction activity naturally fluctuates based on the time of day (e.g., the high activity of the London/New York overlap vs. the quiet Asian lunch session). The RVOL Suite solves this by displaying the **ratio** between the current volume and the moving average volume of the past $N$ periods (`InpPeriod`):

$$\text{RVOL} = \frac{\text{Current Volume}}{\text{Average Volume}(N)}$$

This normalization allows quantitative traders to instantly spot **Institutional Activity (Smart Money / Volume Spikes)** regardless of the asset class, session liquidity, or timeframe. It answers the critical market microstructure question: *"Is the current price move or breakout backed by genuine institutional participation?"*

---

## 2. Methodology and Logic

The calculation compares the active bar's volume against the rolling simple moving average (SMA) of volume over the lookback window $N$, excluding the current bar itself to prevent self-correlation distortion:

$$\text{Average Volume}_t = \frac{1}{N} \sum_{k=1}^{N} \text{Volume}_{t-k}$$

$$\text{RVOL}_t = \frac{\text{Volume}_t}{\text{Average Volume}_t}$$

### Statistical Interpretations

* **$\text{RVOL} = 1.0$ (Blue Histogram):** Volume is exactly average. Normal retail participation.
* **$\text{RVOL} \ge 2.0$ (Orange/Red Histogram):** Volume is double the average (200%+). Institutional activity (Smart Money absorption or aggressive breakout).
* **$\text{RVOL} \le 0.5$ (Gray Histogram):** Volume is half the average (50% or less). Dormant market, low liquidity, no professional interest.

---

## 3. Advanced MQL5 MTF Implementation (The Warping Solution)

### A. The Live-Bar Warping Problem

In standard MTF implementations, updating the indicator separate-window tick-by-tick results in a highly distorted "jagged" or "fűrészfog" shape on the current forming HTF bar. Because standard `OnCalculate` only updates the very last lower timeframe (LTF) index (`rates_total - 1`), the previous LTF bars belonging to the active forming HTF block retain stale historic tick states.

### B. The Forming LTF Block Flat-Force Solution

`RVOL_MTF_Pro` resolves this issue by implementing the **Forming LTF Block Flat-Force** step-alignment algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

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

By forcing a full-block rewrite on every live tick, the active HTF step remains perfectly flat and responsive in real-time, matching institutional charting standards.

### C. Dynamic Volume Routing Pipeline on HTF

To ensure complete robustness across all asset classes, the MTF version dynamically queries the broker's real volume limit (`SYMBOL_VOLUME_LIMIT`). If real volume is available (e.g. Stocks, Futures, Crypto), it uses `CopyRealVolume` to pull HTF data. If only tick volume is available (e.g. Forex, CFD), it falls back to `CopyTickVolume`. This makes the MTF version 100% compliant with the standard `RVOL_Pro` design.

### D. Asynchronous Timer Guard & Incremental O(1) Calculator

* **Background Timer:** High-frequency MTF data requests often suffer from terminal loading gaps. A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as history is ready.

* **O(1) Live-Tick Volume:** Historical volume states are kept static. On every live tick, the latest HTF volume is copied, and the calculator is executed incrementally on only the live index (`g_htf_count - 1`), optimizing CPU cycles.

---

## 4. Parameters

### A. Common Parameters

* **Average Volume Period (`InpPeriod`):** The lookback window ($N$) for the average volume calculation (Default: `20` bars).

* **High Activity Threshold (`InpThreshold`):** The ratio level where volume is considered "High/Institutional" (Default: `2.0`). This controls when the histogram turns Orange/Red.

### B. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate Relative Volume on (Default: `PERIOD_M5`).

---

## 5. Usage and Interpretation

### A. Breakout Confirmation (The "Fuel")

Never trade a breakout from a consolidation (Squeeze) unless accompanied by **High RVOL (Orange/Red Bar)**. A breakout attempt on **Low RVOL (Gray Bar)** is a volume-dry fakeout or a trap. Real breakouts require institutional fuel.

### B. Climatic Volume Exhaustion (Absorption)

When a trend-ending candlestick (e.g. a "Pin Bar", "Doji" or "Hammer") is accompanied by a massive, climatic volume spike (**$\text{RVOL} \ge 3.0$**):

* This indicates high-volume **Institutional Absorption** (Smart Money is absorbing all aggressive orders, marking the end of the trend).
* *Trading Action:* Prepare for an immediate, high-probability trend reversal.

### C. Top-Down Volume Alignment (MTF Core Strategy)

1. **Macro Volume Filter (H1/H4):** Apply `RVOL_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **Volatility Squeeze Plays:** If the lower timeframe is in a tight squeeze, wait for the **H1 MTF RVOL** to turn **Orange/Red ($\ge 2.0$)**. This signals that institutional volume has entered the higher timeframe, validating the breakout on the lower timeframe.
3. **No-Trade Zone:** If the macro HTF RVOL is consistently **Gray ($\le 0.5$)**, the market lacks professional interest. Stand aside and avoid trading consolidations.
