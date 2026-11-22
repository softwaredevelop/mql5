# MESA Adaptive Moving Average (MAMA) Pro (v2.00)

## Institutional Multi-Timeframe Phase-Adaptive DSP Trend Filter Suite with Hilbert Transform Analytics

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**MESA Adaptive Moving Average (MAMA) Pro (v2.00)** is the flagship non-linear digital signal processing (DSP) trend filter of the Professional MQL5 Suite. Developed by rocket scientist and financial engineer **John Ehlers** (2001, *MESA and Verifying Technical Indicators*), MAMA solves the fundamental tradeoff of technical analysis: **the conflict between responsiveness and noise reduction**.

Conventional moving averages (SMA, EMA, LWMA) apply fixed smoothing coefficients ($\alpha$), resulting in significant phase lag during rapid trend accelerations and severe whipsaws during sideways market chop.

**MAMA dynamically modulates its smoothing rate ($\alpha$) bar-by-bar based on the rate of change of the market's instantaneous Hilbert Transform phase angle ($\Delta \text{Phase}$)**. When combined with its secondary companion filter, **FAMA (Following Adaptive Moving Average)**, the suite delivers ultra-clean trend-following crossovers with near-zero lag in trends and horizontal flattening during consolidations:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                     MAMA PRO ARCHITECTURAL OVERVIEW                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Hilbert Transform Pipeline  • Continuous phase & quadrature ($I, Q$) │
│                                  analytical signal decomposition       │
│                                • Homodyne Discriminator cycle detection│
├────────────────────────────────────────────────────────────────────────┤
│ 2. Dynamic Phase-Rate Alpha    • FastLimit in trends (Zero-Lag Hugging)│
│                                • SlowLimit in chop (Horizontal Plateau)│
│                                • Bounds-enforced $\alpha \in [0.05, 0.5]$        │
├────────────────────────────────────────────────────────────────────────┤
│ 3. Dual MAMA / FAMA Crossovers • Secondary filter with halved alpha    │
│                                • Eliminates false consolidation crosses│
├────────────────────────────────────────────────────────────────────────┤
│ 4. 2026 MTF Fast-Path Engine   • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
├────────────────────────────────────────────────────────────────────────┤
│ 5. Trigonometric Epsilon Guard • 1e-5 angle denominator shield         │
│                                • Eliminates atan() division-by-zero    │
│                                • 16 internal state buffers (2048 res)  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & Hilbert Transform DSP Pipeline

```text
                  RAW PRICE INPUT: Standard / Synthetic Heikin Ashi
                                           │
                                           ▼
                            4-Bar WMA Price Pre-Smoothing
                                           │
                                           ▼
                           Hilbert Transform Detrender (HT)
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
In-Phase Component ($I_1$)                                       Quadrature Component ($Q_1$)
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │ Phasor Rotation & Smoothing (0.2 / 0.8)
                                           ▼
                                Phasor Components ($I_2, Q_2$)
                                           │
                                           ▼
                              Homodyne Discriminator (Re, Im)
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
Instantaneous Cycle Period                                   Instantaneous Phase Angle ($\Psi$)
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │ Phase Rate of Change ($\Delta \Psi$)
                                           ▼
                                 Adaptive Alpha Engine
                         $\alpha = \text{FastLimit} / \Delta \Psi$
                                           │
               ┌───────────────────────────┴───────────────────────────┐
               ▼                                                       ▼
        Primary MAMA Line                                       Secondary FAMA Line
   $\alpha \cdot P + (1 - \alpha) \cdot \text{MAMA}$                     $0.5\alpha \cdot \text{MAMA} + (1 - 0.5\alpha) \cdot \text{FAMA}$
```

The mathematical engine executes a 10-step analytical signal processing pipeline on every candle:

### 2.1. Step 1: 4-Bar Weighted Price Pre-Smoothing

The raw price series $P_t$ is filtered using a 4-bar finite impulse response (FIR) triangular kernel to eliminate single-bar microstructure noise:
$$\text{Smooth}_t = (4.0 P_t + 3.0 P_{t-1} + 2.0 P_{t-2} + P_{t-3}) \times 0.1$$

### 2.2. Step 2: Hilbert Transform Detrender

Removes the low-frequency DC trend component using an optimal 7-tap Hilbert transformer weighted by the prior cycle period ($\text{Period}_{t-1}$):
$$G_t = 0.075 \cdot \text{Period}_{t-1} + 0.54$$
$$\text{Detrender}_t = (0.0962 \text{Smooth}_t + 0.5769 \text{Smooth}_{t-2} - 0.5769 \text{Smooth}_{t-4} - 0.0962 \text{Smooth}_{t-6}) \times G_t$$

### 2.3. Steps 3 & 4: In-Phase ($I_1$) and Quadrature ($Q_1$) Phasor Decomposition

Decomposes the detrended signal into orthogonal components separated by a $90^\circ$ phase shift:
$$Q_{1, t} = (0.0962 \text{Detrender}_t + 0.5769 \text{Detrender}_{t-2} - 0.5769 \text{Detrender}_{t-4} - 0.0962 \text{Detrender}_{t-6}) \times G_t$$
$$I_{1, t} = \text{Detrender}_{t-3}$$

Both components are advanced by $90^\circ$ ($jI$ and $jQ$) using identical Hilbert tap weights:
$$jI_t = (0.0962 I_{1, t} + 0.5769 I_{1, t-2} - 0.5769 I_{1, t-4} - 0.0962 I_{1, t-6}) \times G_t$$
$$jQ_t = (0.0962 Q_{1, t} + 0.5769 Q_{1, t-2} - 0.5769 Q_{1, t-4} - 0.0962 Q_{1, t-6}) \times G_t$$

### 2.4. Step 5: Phasor Addition & Recursive Smoothing

Combines components and applies a two-pole exponential smoother:
$$I_{2, t} = 0.2 (I_{1, t} - jQ_t) + 0.8 I_{2, t-1}$$
$$Q_{2, t} = 0.2 (Q_{1, t} + jI_t) + 0.8 Q_{2, t-1}$$

### 2.5. Step 6: Homodyne Discriminator

Multiplies the current phasor by the complex conjugate of the previous bar's phasor to extract instantaneous frequency shift:
$$\text{Re}_t = 0.2 (I_{2, t} I_{2, t-1} + Q_{2, t} Q_{2, t-1}) + 0.8 \text{Re}_{t-1}$$
$$\text{Im}_t = 0.2 (I_{2, t} Q_{2, t-1} - Q_{2, t} I_{2, t-1}) + 0.8 \text{Im}_{t-1}$$

### 2.6. Step 7: Instantaneous Cycle Period with Trigonometric Epsilon Shield

Computes the dominant cycle period. To prevent catastrophic division-by-zero when the arctangent denominator approaches zero, the engine enforces a $1.0\text{e-}5$ angular guard:
$$\theta_t = \text{atan}\left(\frac{\text{Im}_t}{\text{Re}_t}\right) \times \frac{180}{\pi}$$
$$\text{Period}_t = \begin{cases}
\frac{360.0}{\theta_t} & \text{if } |\theta_t| > 1.0\text{e-}5 \\
\text{Period}_{t-1} & \text{otherwise}
\end{cases}$$
The period is dynamically constrained to prevent harmonic doubling or halving:
$$\text{Period}_t \in [0.67 \text{Period}_{t-1}, 1.5 \text{Period}_{t-1}] \quad \land \quad \text{Period}_t \in [6.0, 50.0]$$
$$\text{SmoothPeriod}_t = 0.33 \text{Period}_t + 0.67 \text{SmoothPeriod}_{t-1}$$

### 2.7. Step 8: Phase Angle Derivation
Computes the instantaneous phase angle $\Psi_t$ and its change rate $\Delta \Psi_t$:
$$\Psi_t = \begin{cases} \text{atan}\left(\frac{Q_{1, t}}{I_{1, t}}\right) \times \frac{180}{\pi} & \text{if } I_{1, t} \ne 0 \\ \Psi_{t-1} & \text{otherwise} \end{cases}$$
$$\Delta \Psi_t = \max(1.0, \Psi_{t-1} - \Psi_t)$$

### 2.8. Step 9: Dynamic Adaptive Alpha Calculation
The smoothing factor $\alpha_t$ is dynamically computed and clamped within user-defined bounds:
$$\alpha_t = \frac{\text{FastLimit}}{\Delta \Psi_t}$$
$$\alpha_t = \max(\text{SlowLimit}, \min(\text{FastLimit}, \alpha_t))$$

### 2.9. Step 10: MAMA and FAMA Recurrence
MAMA is computed using the adaptive alpha $\alpha_t$, while FAMA acts as an adaptive follower with half the alpha ($0.5 \alpha_t$):
$$\text{MAMA}_t = \alpha_t P_t + (1.0 - \alpha_t) \text{MAMA}_{t-1}$$
$$\text{FAMA}_t = (0.5 \alpha_t) \text{MAMA}_t + (1.0 - 0.5 \alpha_t) \text{FAMA}_{t-1}$$

---

## 3. Operational Regimes: Trending vs. Cyclic Markets

```text
  Market State    Phase Shift Rate ($\Delta \Psi$)   Adaptive Alpha ($\alpha$)   Indicator Behavioral Character
  ────────────    ──────────────────────────────   ───────────────────────   ──────────────────────────────────────────
  Trending Market Small Phase Advance              $\alpha \to \text{FastLimit}$ (0.50)  ZERO-LAG TRACKING
                  Price moves directionally;       MAMA reacts instantly,    MAMA hugs price candles tightly,
                  phase rate slows down.           accelerating to 0.5.      providing an immediate trendline.

  Cyclic / Chop   Large Phase Advance              $\alpha \to \text{SlowLimit}$ (0.05)  HORIZONTAL STABILIZATION
                  Price oscillates rapidly;        MAMA drops to minimum,    MAMA and FAMA flatten horizontally,
                  phase advances continuously.     ignoring whipsaws.        refusing to crossover during consolidation.
```

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe MAMA/FAMA baselines onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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

### 4.1. Atomic Single-Query Rates Synchronization
Legacy indicators call multiple `Copy*` functions in chained sequences. This causes non-atomic race conditions during volatile live ticks.

`MAMA_Pro` executes a single atomic `CopyRates()` query:
```mql5
MqlRates htf_bulk_rates[];
if(CopyRates(_Symbol, g_calc_timeframe, 0, g_htf_count, htf_bulk_rates) != g_htf_count)
   return 0;
```
All OHLCV arrays are updated in cache simultaneously in nanoseconds.

### 4.2. Two-Pointer Chronological Sweep ($O(N)$ Projection)
Instead of executing an $O(N \cdot M)$ loop calling `iBarShift()` on every chart candle, the engine sweeps chronologically forward using two moving pointers:
```mql5
int htf_ptr = 0;
datetime oldest_htf = h_time[0];

for(int i = 0; i < rates_total; i++)
  {
   datetime t = time[i];
   if(t < oldest_htf)
     {
      BufferMAMA[i] = EMPTY_VALUE;
      BufferFAMA[i] = EMPTY_VALUE;
      continue;
     }

   while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= t)
      htf_ptr++;

   BufferMAMA[i] = h_res_mama[htf_ptr];
   BufferFAMA[i] = h_res_fama[htf_ptr];
  }
```

### 4.3. Live-Tick RAM Mocking & Binary Snapping
During live market ticks where the HTF bar has not closed:
1. Only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is updated.
2. The engine recalculates bar `live_idx` locally.
3. An $O(\log N)$ binary search (`ArrayBsearch`) locates the first LTF bar of the forming HTF block:
   ```mql5
   int first_bar = ArrayBsearch(time, htf_time_current);
   ```
4. Values are direct-vector assigned across the forming block. **Zero `iBarShift()` API calls occur on live ticks.**

---

## 5. Parameters Reference

### === Timeframe Settings ===
* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Timeframe of calculation. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === MAMA Core Settings ===
* **`InpFastLimit`** (*default: `0.50`*): Upper alpha ceiling during strong directional trend regimes. Higher values increase responsiveness (up to 0.9).
* **`InpSlowLimit`** (*default: `0.05`*): Lower alpha floor during sideways consolidation chop. Lower values produce flatter horizontal support/resistance plateaus.
* **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Visual Settings - MAMA Line ===
* **`InpShowMAMA`** (*default: `true`*): Toggles drawing the primary MAMA line.
* **`InpColorMAMA`** (*default: `clrRed`*): Line color for MAMA.
* **`InpStyleMAMA`** (*default: `STYLE_SOLID`*): Line style for MAMA.
* **`InpWidthMAMA`** (*default: `2`*): Line thickness for MAMA.

### === Visual Settings - FAMA Line ===
* **`InpShowFAMA`** (*default: `true`*): Toggles drawing the secondary FAMA line.
* **`InpColorFAMA`** (*default: `clrDodgerBlue`*): Line color for FAMA.
* **`InpStyleFAMA`** (*default: `STYLE_SOLID`*): Line style for FAMA.
* **`InpWidthFAMA`** (*default: `1`*): Line thickness for FAMA.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                         MAMA TRADING PLAYBOOKS                         │
├────────────────────────────────────────────────────────────────────────┤
│ 1. MAMA / FAMA Crossover:      MAMA crossing above FAMA triggers long; │
│                                MAMA crossing below FAMA triggers short.│
│ 2. Sideways Plateau Filtering: MAMA and FAMA flattening into identical │
│                                horizontal lines -> Trading prohibited. │
│ 3. Parabolic Trend Hugging:    MAMA acts as an adaptive trailing stop  │
│                                in runaway momentum impulses.           │
│ 4. MTF Macro Trend Alignment:  Only take M5 long pullbacks when the    │
│                                H4 MAMA is trading above H4 FAMA.       │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Classical MAMA / FAMA Crossover
* **Mechanism:** John Ehlers designed FAMA specifically to serve as an adaptive signal line for MAMA. Because FAMA moves at half the adaptive rate of MAMA, crossovers occur early in a trend turn.
* **Bullish Crossover:** MAMA crosses strictly **above** FAMA $\rightarrow$ Long Trend Initiation.
* **Bearish Crossover:** MAMA crosses strictly **below** FAMA $\rightarrow$ Short Trend Initiation.
* **Filtering Edge:** Unlike EMA crossovers that generate dozens of false signals in chop, MAMA and FAMA rarely cross sideways because both alphas collapse toward `SlowLimit`.

### 6.2. Playbook 2: Sideways Consolidation Flattening (Whipsaw Avoidance)
* **Market State:** Price enters a tight consolidation range; phase advance accelerates.
* **Indicator Behavior:** $\alpha \to 0.05$. MAMA and FAMA become parallel, flat horizontal lines.
* **Execution Rule:** When MAMA and FAMA run flat, **market trend trading is prohibited**. Treat the flat MAMA level as a dynamic pivot / magnet.

### 6.3. Playbook 3: Parabolic Trend Hugging (Trailing Stop Anchor)
* **Mechanism:** In runaway trends, MAMA accelerates to $\alpha = 0.50$, lagging price by only 1 to 2 candles.
* **Execution:** Trail protective stop loss orders strictly behind the MAMA curve. A closed bar crossing MAMA signals that momentum has decoupled, triggering an immediate exit.

### 6.4. Playbook 4: Multi-Timeframe Macro Step Alignment
* Attach an **H4-calculated MAMA Pro** onto an **M5 execution chart**.
* **Quantitative Execution Rule:**
  $$\text{If } \text{BufferMAMA}_{\text{H4 Step}} > \text{BufferFAMA}_{\text{H4 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{BufferMAMA}_{\text{H4 Step}} < \text{BufferFAMA}_{\text{H4 Step}} \implies \text{Short Trades Permitted Only}$$
* Eliminates counter-trend scalping against macro institutional market cycles.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 2 native `INDICATOR_DATA` buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Plot Type | Default Color | Description |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferMAMA` | `DRAW_LINE` | `clrRed` | MESA Adaptive Moving Average (Primary Curve) |
| **1** | `BufferFAMA` | `DRAW_LINE` | `clrDodgerBlue` | Following Adaptive Moving Average (Signal Curve) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to read MAMA Pro values from an automated trading robot:

```mql5
//--- Create handle for Native or MTF MAMA Pro
int handle = iCustom(_Symbol, _Period, "MAMA_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     0.50,                   // InpFastLimit (Alpha ceiling)
                     0.05,                   // InpSlowLimit (Alpha floor)
                     PRICE_CLOSE_STD         // InpSourcePrice (Standard Close)
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create MAMA_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values
double mama_val[], fama_val[];
ArraySetAsSeries(mama_val, true);
ArraySetAsSeries(fama_val, true);

if(CopyBuffer(handle, 0, 1, 2, mama_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, fama_val) == 2)
  {
   double mama_curr = mama_val[0];    // Closed bar (Bar 1)
   double mama_prev = mama_val[1];    // Prior closed bar (Bar 2)
   double fama_curr = fama_val[0];
   double fama_prev = fama_val[1];

   // Example Strategy: Bullish MAMA / FAMA Crossover
   bool is_crossover_long = (mama_prev <= fama_prev && mama_curr > fama_curr);

   // Example Strategy: Bearish MAMA / FAMA Crossover
   bool is_crossover_short = (mama_prev >= fama_prev && mama_curr < fama_curr);

   if(is_crossover_long)
     {
      // Execute Buy Order (Phase-Adaptive Trend Initiation)
     }
   else if(is_crossover_short)
     {
      // Execute Sell Order (Phase-Adaptive Trend Initiation)
     }
  }
```
