# Ehlers Unified Channel Pro (v3.10)

## Institutional Multi-Timeframe Volatility Envelope Suite — Uniting Keltner (ATR), Bollinger (RMS Residual) & Classic StDev Around Zero-Lag Ehlers Centerlines

**Enterprise Ultra Edition — High-Concurrency Composition Facade for MetaTrader 5*

---

## 1. Executive Summary & Single Source of Truth (SSOT) Architecture

**Ehlers Unified Channel Pro (v3.10)** is the all-in-one adaptive volatility envelope overlay of the Professional MQL5 Suite. Rather than maintaining conflicting, isolated channel implementations, it applies the **Composition Facade & Single Source of Truth (SSOT)** software architecture pattern.

The unified engine (`Ehlers_Unified_Channel_Calculator.mqh`) acts as a lightweight router that dynamically instantiates and delegates calculations directly to the core `Ehlers_Bands_Calculator.mqh` and `Ehlers_Channel_Calculator.mqh` engines. This guarantees **100% numerical bit-for-bit parity** across standalone indicators, `%B` oscillators, and downstream Ensemble trading models:

```text
         [ Ehlers_Smoother_Calculator.mqh ]         [ ATR_Calculator.mqh ]
                    │                                          │
         ┌──────────┴──────────────────┐                       │
         ▼                             ▼                       ▼
[ Ehlers_Bands_Calculator.mqh ]       [ Ehlers_Channel_Calculator.mqh ]
  (Bollinger RMS & Classic StDev)       (Keltner-Style ATR Channel)
         │                                     │
         └──────────────────┬──────────────────┘
                            ▼
         [ Ehlers_Unified_Channel_Calculator.mqh ]
           (Composition Facade & Memory Router)
                            │
                            ▼
             Ehlers_Unified_Channel_Pro.mq5
```

### Key Architectural Capabilities

- **3 Quantitative Envelope Modes:** Seamlessly switch between Keltner (ATR), Ehlers Bollinger (RMS Tracking Residual), and Classical Bollinger (StDev) without changing chart templates or EA pipelines.
- **2 Low-Pass Ehlers Centerlines:** Powered by John Ehlers' critically damped **SuperSmoother** ($-12\text{ dB/oct}$ noise rejection) or zero-lag lead-injected **UltimateSmoother**.
- **Pay-Only-For-What-You-Use Memory Model:** Only instantiates the specific underlying calculator required by the active mode (`m_bands_calc` OR `m_channel_calc`), minimizing RAM footprint across 180+ concurrent chart instances.
- **Decoupled Period Architecture:** Configure centerline smoothing (`InpSmoothPeriod`) independently from volatility lookback (`InpVolPeriod`).
- **Hybrid Heikin Ashi Support:** Supports all 7 standard and 7 synthetic Heikin Ashi price sources, plus independent Standard vs. Heikin Ashi ATR routing in Keltner mode.
- **2026 MTF Fast-Path Protocol:** Atomic single-query `CopyRates()`, Two-Pointer Chronological Sweep ($O(N)$ projection), and zero-API live-tick binary snapping.

---

## 2. Mathematical Foundations: Centerlines & Volatility Envelopes

```text
                  RAW MARKET OHLC INPUT (Standard or Heikin Ashi)
                                           │
                                           ▼
                   Centerline Engine: SuperSmoother / UltimateSmoother
                                   (Period: InpSmoothPeriod)
                                           │
       ┌───────────────────────────────────┼───────────────────────────────────┐
       ▼                                   ▼                                   ▼
Mode 1: KELTNER ATR              Mode 2: BOLLINGER RMS               Mode 3: BOLLINGER STDEV
ATR(VolPeriod) · Mult            RMS(P[t-j] - Mid[t-j]) · Mult       StDev(P[t-j] - Mid[t]) · Mult
       │                                   │                                   │
       └───────────────────────────────────┼───────────────────────────────────┘
                                           ▼
                      Upper = Centerline + Offset,   Lower = Centerline - Offset
```

### 2.1. The Centerline Engines (`SuperSmoother` & `UltimateSmoother`)

Both channel models share the exact same adaptive baseline $\text{Centerline}_t$ computed from `InpSmoothPeriod` ($P_s$):

- **`SUPERSMOOTHER`:** 2-pole critically damped Butterworth IIR filter eliminating high-frequency Nyquist aliasing noise with minimal phase lag.
- **`ULTIMATESMOOTHER`:** Feedforward lead-injected 2-pole filter eliminating 100% of recursive phase delay for instantaneous trend tracking.

### 2.2. Mode 1: Keltner Style (`ENVELOPE_KELTNER_ATR`)

Computes channel half-width using Wilder's pipelined Average True Range over `InpVolPeriod` ($P_v$):
$$\text{Offset}_t = \text{ATR}(P_v)_t \times M$$
*Hybrid Capability:* Allows computing the centerline on synthetic Heikin Ashi prices while evaluating true market gaps via `ATR_SOURCE_STANDARD`, or smoothing wicks via `ATR_SOURCE_HEIKIN_ASHI`.

### 2.3. Mode 2: Bollinger RMS Tracking Residual (`ENVELOPE_BOLLINGER_RMS`)

Computes the Root Mean Square (RMS) of the instantaneous tracking residual between the price series and the Ehlers filter at each bar $t-j$:
$$\sigma_{\text{RMS}, t} = \sqrt{\left(\sum_{j=0}^{P_v-1} (P_{t-j} - \text{Centerline}_{t-j})^2\right) \times \frac{1}{P_v}}$$
$$\text{Offset}_t = \sigma_{\text{RMS}, t} \times M$$
*Mathematical Advantage:* Unlike traditional Bollinger Bands, which balloon artificially during strong $45^\circ$ trends because older prices sit far away from the current mean, **RMS Residual measures true perpendicular noise around the trend curve**. Bands remain tight and responsive during clean trends, expanding only when genuine microstructure volatility spikes.

### 2.4. Mode 3: Bollinger Classic Standard Deviation (`ENVELOPE_BOLLINGER_STDEV`)

Computes classical statistical dispersion relative to the **current** centerline value $\text{Centerline}_t$:
$$\sigma_{\text{StDev}, t} = \sqrt{\left(\sum_{j=0}^{P_v-1} (P_{t-j} - \text{Centerline}_t)^2\right) \times \frac{1}{P_v}}$$
$$\text{Offset}_t = \sigma_{\text{StDev}, t} \times M$$
*Operational Advantage:* Accurately reflects trend slope expansion, making it ideal for identifying classical volatility squeezes and parabolic exhaustion.

### 2.5. Final Envelope Boundaries

$$\text{UpperBand}_t = \text{Centerline}_t + \text{Offset}_t$$
$$\text{LowerBand}_t = \text{Centerline}_t - \text{Offset}_t$$

---

## 3. Quantitative Mode Comparison Matrix

| Property / Behavior | Mode 1: Keltner ATR | Mode 2: Bollinger RMS | Mode 3: Bollinger StDev |
| :--- | :---: | :---: | :---: |
| **Volatility Metric** | Wilder's True Range (ATR) | Filter Tracking Residual (RMS) | Static Mean Dispersion (StDev) |
| **Gap Sensitivity** | **High** (Captures overnight gaps) | Moderate | Moderate |
| **Trend Expansion** | Smooth & Constant Width | **Tight** (Tracks noise only) | **Wide** (Balloons with slope) |
| **Squeeze Detection** | Poor | Moderate | **Exceptional** |
| **Optimal Role** | Trend Breakouts & Trailing Stops | Tight Channel Trend Riding | Volatility Squeezes & Mean Reversion |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Unified Channels onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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

### === Centerline Smoother Settings ===

- **`InpSmootherType`** (*default: `SUPERSMOOTHER`*): Selects between `SUPERSMOOTHER` (critically damped 2-pole Butterworth) and `ULTIMATESMOOTHER` (zero-lag lead-injected filter).

- **`InpSmoothPeriod`** (*default: `20`*): Cutoff smoothing period for the Centerline.
- **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Volatility Envelope Mode ===

- **`InpEnvelopeMode`** (*default: `ENVELOPE_BOLLINGER_RMS`*):
  - `ENVELOPE_KELTNER_ATR`: Keltner-style ATR channel.
  - `ENVELOPE_BOLLINGER_RMS`: Ehlers RMS Residual tracking bands.
  - `ENVELOPE_BOLLINGER_STDEV`: Classical StDev bands around the Ehlers smoother.

- **`InpVolPeriod`** (*default: `20`*): Lookback window for ATR or RMS/StDev dispersion calculation.
- **`InpMultiplier`** (*default: `2.0`*): Multiplier applied to ATR, RMS, or StDev to define channel width.
- **`InpAtrSource`** (*default: `ATR_SOURCE_STANDARD`*): Selects Standard or Heikin Ashi True Range calculation (active exclusively when `InpEnvelopeMode = ENVELOPE_KELTNER_ATR`).

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
│                   EHLERS UNIFIED CHANNEL PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Zero-Lag Keltner Breakout: UltimateSmoother + ATR(14) -> Early      │
│                               breakouts with true range protection.    │
│ 2. RMS Tight Trend Riding:    SuperSmoother + RMS(20) -> Clean dynamic │
│                               channel stops without trend ballooning.  │
│ 3. Classic Squeeze Reversion: SuperSmoother + StDev(20) -> Fading      │
│                               2.5-sigma extremes back to Centerline.   │
│ 4. MTF Macro Step Alignment:  Only take M5 long breakouts when price   │
│                               is holding above the H4 Centerline.      │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Zero-Lag Keltner Breakout (`ENVELOPE_KELTNER_ATR`)

- **Configuration:** `InpSmootherType = ULTIMATESMOOTHER`, `InpEnvelopeMode = ENVELOPE_KELTNER_ATR`, `InpVolPeriod = 14`, `InpMultiplier = 2.0`.

- **Mechanism:** Combines the zero-lag turning speed of the UltimateSmoother with steady ATR envelopes.
- **Execution:** Enter long when a candle closes decisively above the Upper Band during rising ATR. Trail stop-loss along the Centerline.

### 6.2. Playbook 2: Tight-Channel Trend Riding (`ENVELOPE_BOLLINGER_RMS`)

- **Configuration:** `InpSmootherType = SUPERSMOOTHER`, `InpEnvelopeMode = ENVELOPE_BOLLINGER_RMS`, `InpVolPeriod = 20`, `InpMultiplier = 2.0`.

- **Mechanism:** Because RMS measures tracking residual, the bands hug smooth trend channels tightly without inflating.
- **Execution:** Enter pullbacks to the Centerline in established trends; take partial profits when price tags the outer RMS boundary and prints rejection wicks.

### 6.3. Playbook 3: Mean-Reversion Squeeze & Fade (`ENVELOPE_BOLLINGER_STDEV`)

- **Configuration:** `InpSmootherType = SUPERSMOOTHER`, `InpEnvelopeMode = ENVELOPE_BOLLINGER_STDEV`, `InpVolPeriod = 20`, `InpMultiplier = 2.5`.

- **Execution:** In ranging/sideways market regimes, fade extreme price spikes exceeding the $2.5\sigma$ Upper/Lower Band back toward the stationary SuperSmoother Centerline.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment

- Attach an **H4-calculated Ehlers Unified Channel Pro** onto an **M15 execution chart**.

- **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{Bid} < \text{BufferMiddle}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
- Eliminates counter-trend scalping against higher-timeframe institutional volatility channels.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 3 native `INDICATOR_DATA` buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferUpper` | `DRAW_LINE` | `clrDodgerBlue` | Upper Volatility Envelope Band |
| **1** | `BufferLower` | `DRAW_LINE` | `clrDodgerBlue` | Lower Volatility Envelope Band |
| **2** | `BufferMiddle` | `DRAW_LINE` | `clrCrimson` | Ehlers Centerline (`SuperSmoother` / `UltimateSmoother`) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the currently forming live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read Ehlers Unified Channel Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF Ehlers Unified Channel Pro (Bollinger RMS Mode)
int handle = iCustom(_Symbol, _Period, "Ehlers_Unified_Channel_Pro",
                     PERIOD_CURRENT,             // InpTimeframe
                     SUPERSMOOTHER,              // InpSmootherType
                     20,                         // InpSmoothPeriod
                     PRICE_CLOSE_STD,            // InpSourcePrice
                     ENVELOPE_BOLLINGER_RMS,     // InpEnvelopeMode
                     20,                         // InpVolPeriod
                     2.0,                        // InpMultiplier
                     ATR_SOURCE_STANDARD         // InpAtrSource
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Ehlers_Unified_Channel_Pro handle.");
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
