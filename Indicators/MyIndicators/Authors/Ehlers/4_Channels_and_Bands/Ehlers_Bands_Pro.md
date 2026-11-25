# Ehlers Bands Pro (v2.00)

## Institutional Multi-Timeframe RMS & Standard Deviation Volatility Envelope Suite Around Zero-Lag Ehlers Centerlines

**Enterprise Ultra Edition — High-Concurrency Clean-Slate DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & Clean-Slate Architecture

**Ehlers Bands Pro (v2.00)** is the standalone statistical volatility envelope overlay of the Professional MQL5 Suite. Engineered around a completely modernized, **Clean-Slate Zero-Pointer Architecture (`Ehlers_Bands_Calculator.mqh` v3.00)**, it pairs John Ehlers’ low-pass centerlines (**SuperSmoother** and **UltimateSmoother**) with two selectable dispersion models: **Ehlers RMS Tracking Residual** and **Classical Standard Deviation**.

Standard Bollinger Bands suffer from two critical defects: slow arithmetic SMA centerlines that introduce massive phase lag, and static-mean standard deviation calculations that artificially balloon during clean directional trends. **Ehlers Bands Pro eliminates both defects while serving as the Single Source of Truth (SSOT) engine for downstream `%B` oscillators and Ensemble models**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                    EHLERS BANDS ARCHITECTURAL OVERVIEW                 │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Zero-Pointer Stack Design  • Static global calculator instance and  │
│                                 stack-embedded Smoother engine         │
│                               • Zero dynamic heap churn or pointer risk│
├────────────────────────────────────────────────────────────────────────┤
│ 2. Single-Pass Price Routing  • Computes Standard or Synthetic Heikin  │
│                                 Ashi prices strictly once per tick     │
│                               • Feeds prepared price straight to center│
├────────────────────────────────────────────────────────────────────────┤
│ 3. Dual Dispersion Engines    • Mode A: RMS Tracking Residual (Tight)  │
│                               • Mode B: Classic StDev (Squeeze/Reversion)│
├────────────────────────────────────────────────────────────────────────┤
│ 4. Decoupled Periods          • Tune Centerline cutoff (SmoothPeriod)  │
│                                 independently of BandPeriod dispersion │
├────────────────────────────────────────────────────────────────────────┤
│ 5. 2026 MTF Fast-Path Protocol• Atomic single-query CopyRates() sync   │
│                               • Two-Pointer Chronological Sweep (O(N)) │
│                               • Binary search snapping (ArrayBsearch)  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations: Centerlines & Dual Dispersion Models

```text
                  RAW MARKET OHLC INPUT (Standard or Heikin Ashi)
                                           │
                                           ▼
                       Single-Pass Price Series Preparation
                                           │
                                           ▼
                   Centerline Engine: SuperSmoother / UltimateSmoother
                                   (Period: InpSmoothPeriod)
                                           │
                     ┌─────────────────────┴─────────────────────┐
                     ▼                                           ▼
      Mode A: BANDS_RMS_RESIDUAL                    Mode B: BANDS_CLASSIC_STDEV
      RMS(P[t-j] - Centerline[t-j])                 StDev(P[t-j] - Centerline[t])
                     │                                           │
                     └─────────────────────┬─────────────────────┘
                                           │ Multiplied by InpMultiplier
                                           ▼
                      Upper = Centerline + Offset,   Lower = Centerline - Offset
```

### 2.1. Stage 1: Single-Pass Price & Centerline Synthesis

The engine prepares the input price vector $P_t$ strictly once (supporting all 7 Standard and 7 synthetic Heikin Ashi modes) and routes it into the stack-embedded `CEhlersSmootherCalculator` (`InpSmoothPeriod`):

- **`SUPERSMOOTHER`:** 2-pole critically damped Butterworth IIR filter eliminating Nyquist aliasing noise ($-12\text{ dB/oct}$) with minimal phase delay.
- **`ULTIMATESMOOTHER`:** Feedforward lead-injected 2-pole filter eliminating 100% of recursive phase lag for instantaneous turns.

### 2.2. Stage 2A: Ehlers RMS Tracking Residual (`BANDS_RMS_RESIDUAL`)

Measures the Root Mean Square (RMS) of the instantaneous tracking error between the asset price and the Ehlers filter at each historical bar $t-j$ across `InpBandPeriod` ($P_b$):
$$\sigma_{\text{RMS}, t} = \sqrt{\left(\sum_{j=0}^{P_b-1} (P_{t-j} - \text{Centerline}_{t-j})^2\right) \times \frac{1}{P_b}}$$

*Why RMS Residual Outperforms Classical Bollinger Bands:* In traditional Bollinger Bands, if a market trends steadily at $45^\circ$, price $P_{t-20}$ lies far below $\text{Centerline}_t$. Squaring $(P_{t-20} - \text{Centerline}_t)$ artificially inflates the band width even if the market has almost zero volatility! **RMS Residual measures perpendicular noise around the trend slope**, keeping bands tight and realistic during trends and expanding strictly when real microstructure volatility increases.

### 2.3. Stage 2B: Classical Standard Deviation (`BANDS_CLASSIC_STDEV`)

Measures traditional statistical dispersion around the **current** centerline value $\text{Centerline}_t$:
$$\sigma_{\text{StDev}, t} = \sqrt{\left(\sum_{j=0}^{P_b-1} (P_{t-j} - \text{Centerline}_t)^2\right) \times \frac{1}{P_b}}$$

*Operational Role:* Captures absolute price expansion relative to historical levels, providing crisp contraction structures for volatility squeeze setups.

### 2.4. Final Envelope Boundaries

$$\text{Offset}_t = \sigma_t \times \text{InpMultiplier}$$
$$\text{UpperBand}_t = \text{Centerline}_t + \text{Offset}_t$$
$$\text{LowerBand}_t = \text{Centerline}_t - \text{Offset}_t$$

---

## 3. Dispersion Mode Comparison Matrix

| Metric / Property | Mode A: `BANDS_RMS_RESIDUAL` | Mode B: `BANDS_CLASSIC_STDEV` |
| :--- | :---: | :---: |
| **Mathematical Reference** | Instantaneous Residual ($P_{t-j} - \text{Mid}_{t-j}$) | Static Current Mean ($P_{t-j} - \text{Mid}_t$) |
| **Behavior in Strong Trends** | **Tight & Parallel:** Tracks perpendicular noise only. | **Ballooning:** Widens substantially with trend slope. |
| **Band Tag Sensitivity** | High; provides early breakout/exhaustion touches. | Moderate; requires parabolic acceleration to tag. |
| **Squeeze Clarity** | Moderate. | **Exceptional:** Sharp visual bottlenecks before breakouts. |
| **Optimal Market Role** | Trend-channel riding & pullback entries. | Consolidation squeeze breakouts & mean reversion. |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Ehlers Bands onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

```text
  HTF Domain (e.g. H1)
  [ HTF Bar 0 ]────────────────────────>[ HTF Bar 1 ]────────────────────────>[ HTF Forming ]
        │                                     │                                     │
        ▼ (Chronological 2-Pointer Projection)▼                                     ▼
  LTF Domain (e.g. M5)
  [m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5]
  └───────────────────┘ └───────────────────┘ └───────────────────┘ └───────────────────────┘
     Flat Step 0           Flat Step 1           Flat Step 2           Forming Block (Live)
```

1. **Atomic Single-Query Rates Synchronization:** A single `CopyRates()` query acquires all OHLC bars for the HTF domain simultaneously in nanoseconds.
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Sweeps forward in a single linear pass, projecting Upper, Lower, and Centerline values onto chart candles with zero `iBarShift()` API calls.
3. **Live-Tick Isolated RAM Mocking:** On incoming live ticks within an open HTF bar, only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is recalculated. An $O(\log N)$ binary search (`ArrayBsearch`) snaps to the forming block start and vector-assigns values in nanoseconds.

---

## 5. Parameters Reference

### === Timeframe Settings ===

- **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Ehlers Bands Core Settings ===

- **`InpCenterlineType`** (*default: `SUPERSMOOTHER`*): Selects between `SUPERSMOOTHER` (critically damped 2-pole Butterworth) and `ULTIMATESMOOTHER` (zero-lag lead-injected filter).

- **`InpSmoothPeriod`** (*default: `20`*): Cutoff smoothing period for the Centerline.
- **`InpBandsMode`** (*default: `BANDS_RMS_RESIDUAL`*):
  - `BANDS_RMS_RESIDUAL`: Ehlers RMS Tracking Residual.
  - `BANDS_CLASSIC_STDEV`: Classical Standard Deviation around current filter.
- **`InpBandPeriod`** (*default: `20`*): Lookback window for dispersion calculation.
- **`InpMultiplier`** (*default: `2.0`*): Multiplier applied to RMS or StDev to define channel width.
- **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Visual Settings - Outer Bands ===

- **`InpColorUpper`** (*default: `clrDodgerBlue`*): Color of the Upper Band.

- **`InpColorLower`** (*default: `clrDodgerBlue`*): Color of the Lower Band.
- **`InpStyleBands`** (*default: `STYLE_SOLID`*): Line style for both outer bands.
- **`InpWidthBands`** (*default: `1`*): Line width for both outer bands.

### === Visual Settings - Centerline ===

- **`InpShowMiddle`** (*default: `true`*): Toggles drawing the Centerline.

- **`InpColorMiddle`** (*default: `clrCrimson`*): Line color for the Centerline.
- **`InpStyleMiddle`** (*default: `STYLE_DOT`*): Line style for the Centerline.
- **`InpWidthMiddle`** (*default: `1`*): Line thickness for the Centerline.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                       EHLERS BANDS PLAYBOOKS                           │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Tight-Channel Trend Riding: RMS bands remain parallel in trends ->  │
│                                Enter pullbacks to Centerline; scale out│
│                                at Upper/Lower band touches.            │
│ 2. Volatility Squeeze Break:   Classic StDev bands pinch tightly ->    │
│                                Enter decisive bar close outside band.  │
│ 3. Extreme Exhaustion Fade:    Price spikes beyond 2.5σ/3.0σ RMS band  │
│                                and prints reversal wick -> Mean revert.│
│ 4. MTF Macro Step Alignment:   Only take M5 long breakouts when price  │
│                                is holding above H4 Centerline.         │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Tight-Channel Trend Riding (`BANDS_RMS_RESIDUAL`)

- **Configuration:** `InpCenterlineType = SUPERSMOOTHER`, `InpBandsMode = BANDS_RMS_RESIDUAL`, `InpMultiplier = 2.0`.

- **Mechanism:** Because RMS measures tracking residual, bands hug directional channels tightly without artificial ballooning.
- **Execution:** Enter trend continuations on pullbacks that hold the SuperSmoother Centerline; take partial profits when price tags the outer band.

### 6.2. Playbook 2: Volatility Squeeze Breakout (`BANDS_CLASSIC_STDEV`)

- **Configuration:** `InpCenterlineType = ULTIMATESMOOTHER`, `InpBandsMode = BANDS_CLASSIC_STDEV`, `InpMultiplier = 2.0`.

- **Mechanism:** When the market consolidates, the bands pinch into a narrow bottleneck.
- **Execution:** Enter in the direction of the first candle that closes aggressively outside the Upper or Lower Band as band boundaries flare outward.

### 6.3. Playbook 3: Mean-Reversion Exhaustion Fade

- **Configuration:** `InpMultiplier = 2.5` or `3.0`.

- **Execution:** In ranging markets, spikes piercing beyond $2.5 \times \sigma_{\text{RMS}}$ represent statistical exhaustion. Fade rejection wicks back toward the stationary Centerline.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment

- Attach an **H4-calculated Ehlers Bands Pro** onto an **M15 execution chart**.

- **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{Bid} < \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
- Eliminates counter-trend scalping against higher-timeframe institutional trend regimes.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native `INDICATOR_DATA` buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferUpper` | `DRAW_LINE` | `clrDodgerBlue` | Upper Volatility Envelope Band |
| **1** | `BufferLower` | `DRAW_LINE` | `clrDodgerBlue` | Lower Volatility Envelope Band |
| **2** | `BufferMiddle` | `DRAW_LINE` | `clrCrimson` | Ehlers Centerline (`SuperSmoother` / `UltimateSmoother`) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Internal Price Export for Downstream Modules (`GetPriceBuffer`)

For developers embedding `CEhlersBandsCalculator` directly into custom `%B` oscillators or Ensemble voting engines, `GetPriceBuffer(double &dest_array[])` exports the exact single-pass prepared price array (Standard or Synthetic Heikin Ashi) with `2048`-element capacity reservations, enabling seamless normalized `%B` computation:
$$\%B_t = 100 \times \frac{\text{Price}_t - \text{LowerBand}_t}{\text{UpperBand}_t - \text{LowerBand}_t}$$

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Ehlers Bands Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Ehlers Bands Pro (RMS Residual Mode)
int handle = iCustom(_Symbol, _Period, "Ehlers_Bands_Pro",
                     PERIOD_CURRENT,             // InpTimeframe
                     SUPERSMOOTHER,              // InpCenterlineType
                     20,                         // InpSmoothPeriod
                     BANDS_RMS_RESIDUAL,         // InpBandsMode
                     20,                         // InpBandPeriod
                     2.0,                        // InpMultiplier
                     PRICE_CLOSE_STD             // InpSourcePrice
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Ehlers_Bands_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double upper_val[], lower_val[], mid_val[];
ArraySetAsSeries(upper_val, true);
ArraySetAsSeries(lower_val, true);
ArraySetAsSeries(mid_val,   true);

if(CopyBuffer(handle, 0, 1, 2, upper_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, lower_val) == 2 &&
   CopyBuffer(handle, 2, 1, 2, mid_val)   == 2)
  {
   double upper_curr = upper_val[0];    // Closed bar (Bar 1)
   double lower_curr = lower_val[0];
   double mid_curr   = mid_val[0];
   double close_curr = iClose(_Symbol, _Period, 1);

   // Example Strategy: Breakout above Upper RMS Band
   if(close_curr > upper_curr)
     {
      // Execute Long Breakout / Momentum Expansion Order
     }
  }
```
