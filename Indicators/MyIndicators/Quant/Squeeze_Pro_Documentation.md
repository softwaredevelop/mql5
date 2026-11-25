# Squeeze Pro (v4.00)

## Institutional Multi-Timeframe TTM Volatility Squeeze & 4-Color Linear Regression Momentum Suite

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & Volatility Compression Theory

**Squeeze Pro (v4.00)** is the premier volatility compression and explosive breakout suite of the Professional MQL5 Suite. Directly implementing **John Carter’s TTM Squeeze** quantitative methodology, it models the fundamental thermodynamic rhythm of financial markets: **markets alternate perpetually between periods of low-volatility compression (coiling) and high-volatility directional expansion**.

When institutional participants accumulate or distribute large positions silently inside tight trading ranges, realized standard deviation collapses. **Squeeze Pro detects these hidden coiling regimes by comparing Bollinger Bands against Keltner Channels, and pairs the compression trigger with a closed-form Linear Regression momentum oscillator to predict breakout direction and exhaustion**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                    SQUEEZE PRO ARCHITECTURAL OVERVIEW                  │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Dual Volatility Squeeze     • Bollinger Bands (StDev) vs. Keltner   │
│    Detection Engine              Channels (ATR)                        │
│                                • Independent ATR Period & Hybrid Source│
├────────────────────────────────────────────────────────────────────────┤
│ 2. Closed-Form LinReg Momentum • Division-free O(1) Least Squares fit  │
│                                • Precomputed Sum(x²) & midpoint terms  │
│                                • Genuine TTM Delta baseline derivation │
├────────────────────────────────────────────────────────────────────────┤
│ 3. 4-Color Thermal Momentum    • LightSkyBlue / DeepSkyBlue (Bullish)  │
│    & 2-Color State Dots        • OrangeRed / Coral (Bearish)           │
│                                • Zero-Line Dots: Red (ON), Lime (Fired)│
├────────────────────────────────────────────────────────────────────────┤
│ 4. Authentic Heikin Ashi Core  • True _HA subclasses for BB & KC       │
│                                • Synthesized HA candles for TTM Delta  │
├────────────────────────────────────────────────────────────────────────┤
│ 5. 2026 MTF Fast-Path Protocol • Atomic single-query CopyRates() sync  │
│                                • Two-Pointer Chronological Sweep (O(N))│
│                                • Binary search snapping (ArrayBsearch) │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Mathematical Foundations & TTM Squeeze DSP Pipeline

```text
                  RAW MARKET OHLC INPUT (Standard or Heikin Ashi)
                                           │
       ┌───────────────────────────────────┴───────────────────────────────────┐
       ▼                                                                       ▼
Bollinger Bands Engine                                              Keltner Channels Engine
SMA(P) ± BBMult · σ(P)                                              SMA(P) ± KCMult · ATR(ATRPeriod)
       │                                                                       │
       └───────────────────────────────────┬───────────────────────────────────┘
                                           │ Squeeze Check
                                           ▼
                   Squeeze State = (BB_Upper < KC_Upper) && (BB_Lower > KC_Lower)
                                  [ Red Dot = ON | Lime Dot = Fired ]
                                           │
                                           ▼
                           TTM Baseline Delta Calculation
                       Δ[t] = Close[t] - Avg(DonchianMid[t], SMA[t])
                                           │
                                           ▼
                   Closed-Form Linear Regression Endpoint (MomPeriod)
                             (Division-Free Precomputed ALU)
                                           │
                                           ▼
                       4-Color Thermal Momentum Histogram Output
```

### 2.1. Stage 1: The Volatility Squeeze State Condition

The engine runs `CBollingerBandsCalculator` (`InpPeriod`, `InpBBMult`) and `CKeltnerChannelCalculator` (`InpPeriod`, `InpAtrPeriod`, `InpKCMult`, `InpAtrSource`) in parallel:
$$\text{SqueezeActive}_t = (\text{BB}_{\text{Upper}, t} < \text{KC}_{\text{Upper}, t}) \;\land\; (\text{BB}_{\text{Lower}, t} > \text{KC}_{\text{Lower}, t})$$

- **Squeeze ON (`1.0` / Red Dot):** Volatility has compressed below historical Average True Range boundaries. An explosive move is coiling.
- **Squeeze OFF / Fired (`0.0` / Lime Dot):** Bollinger Bands have expanded back outside Keltner Channels, confirming that the volatility breakout has ignited.

### 2.2. Stage 2: TTM Delta Baseline Derivation

Computes the instantaneous price displacement relative to the midpoint of the Donchian Channel and Moving Average:
$$\text{DonchianMid}_t = \frac{\max_{k=0 \dots P-1}(\text{High}_{t-k}) + \min_{k=0 \dots P-1}(\text{Low}_{t-k})}{2}$$
$$\text{AvgBaseline}_t = \frac{\text{DonchianMid}_t + \text{SMA}(P)_t}{2}$$
$$\Delta_t = \text{Close}_t - \text{AvgBaseline}_t$$

### 2.3. Stage 3: Division-Free Closed-Form Linear Regression Momentum

Fits an Ordinary Least Squares (OLS) regression line across the trailing $N = \text{InpMomPeriod}$ bars of $\Delta_t$. By centering the time coordinate $x_k$ around zero ($x_k = k - \frac{N-1}{2}$ for $k = 0 \dots N-1$):
$$\sum_{k=0}^{N-1} x_k = 0, \quad\quad \sum_{k=0}^{N-1} x_k^2 = \frac{N(N^2 - 1)}{12}$$

To eliminate runtime divisions, `m_half_len`, `m_inv_mom_period`, and `m_inv_sum_xx` are precomputed strictly once in `Init()`:
$$\text{Slope}_t = \left(\sum_{k=0}^{N-1} x_k \cdot \Delta_{t - N + 1 + k}\right) \times \text{m\_inv\_sum\_xx}$$
$$\text{Intercept}_t = \left(\sum_{k=0}^{N-1} \Delta_{t - N + 1 + k}\right) \times \text{m\_inv\_mom\_period}$$
$$\text{Momentum}_t = \text{Intercept}_t + \text{Slope}_t \times \text{m\_half\_len}$$

---

## 3. The 4-Color Thermal Momentum & State Matrix

### 3.1. Momentum Histogram Classification (`BufferMomColor`)

| Color Index | Default Color | Mathematical Condition | Quantitative Market Regime |
| :---: | :---: | :--- | :--- |
| **`0.0`** | `clrLightSkyBlue` | $\text{Mom}_t \ge 0.0 \;\land\; \text{Mom}_t \ge \text{Mom}_{t-1}$ | **Bullish Expanding:** Strong upward impulse acceleration. |
| **`1.0`** | `clrDeepSkyBlue` | $\text{Mom}_t \ge 0.0 \;\land\; \text{Mom}_t < \text{Mom}_{t-1}$ | **Bullish Decelerating:** Upward momentum waning; watch for profit-taking. |
| **`2.0`** | `clrOrangeRed` | $\text{Mom}_t < 0.0 \;\land\; \text{Mom}_t \le \text{Mom}_{t-1}$ | **Bearish Expanding:** Strong downward impulse acceleration. |
| **`3.0`** | `clrCoral` | $\text{Mom}_t < 0.0 \;\land\; \text{Mom}_t > \text{Mom}_{t-1}$ | **Bearish Decelerating:** Downward momentum waning; watch for short covering. |

### 3.2. Zero-Line Squeeze Dots (`BufferSqueezeColors`)

| Color Index | Default Color | Condition | Operational Interpretation |
| :---: | :---: | :--- | :--- |
| **`0.0`** | `clrLime` | Squeeze OFF / Fired | Volatility expansion active; breakout has triggered. |
| **`1.0`** | `clrRed` | Squeeze ON | Bollinger Bands inside Keltner Channels; volatility compression coiling. |

---

## 4. Enterprise MTF Fast-Path Protocol

When projecting higher-timeframe Squeeze states onto lower-timeframe execution charts (`InpTimeframe > Period()`), the engine eliminates legacy MTF architectural bottlenecks:

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
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Sweeps forward in a single linear pass, projecting all 4 output buffers (`BufferMom`, `BufferMomColor`, `BufferSqueeze`, `BufferSqueezeColors`) onto chart candles with zero `iBarShift()` API calls.
3. **Live-Tick Isolated RAM Mocking:** On incoming live ticks within an open HTF bar, only the active forming candle in RAM (`live_idx = g_htf_count - 1`) is recalculated. An $O(\log N)$ binary search (`ArrayBsearch`) snaps to the forming block start and vector-assigns values in nanoseconds.

---

## 5. Parameters Reference

### === Timeframe Settings ===

- **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Calculation timeframe. Set to `PERIOD_CURRENT` for standard zero-lag execution, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline.

### === Squeeze Core Settings ===

- **`InpPeriod`** (*default: `20`*): Lookback period for Bollinger Bands, Keltner Channel Basis SMA, and Donchian Midpoint.

- **`InpBBMult`** (*default: `2.0`*): Bollinger Bands Standard Deviation multiplier.
- **`InpAtrPeriod`** (*default: `20`*): Independent lookback window for Keltner Channel Average True Range (e.g. 20 or 14).
- **`InpKCMult`** (*default: `1.5`*): Keltner Channel ATR multiplier.
- **`InpAtrSource`** (*default: `ATR_SOURCE_STANDARD`*): Selects Standard or Heikin Ashi True Range calculation for Keltner Channels.
- **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Global price source. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### === Momentum Settings (Linear Regression) ===

- **`InpMomPeriod`** (*default: `20`*): Lookback length for the TTM Linear Regression endpoint oscillator.

### === Visual Settings - Momentum Histogram ===

- **`InpColorBullExp`** (*default: `clrLightSkyBlue`*): Bullish expanding bar color.

- **`InpColorBullDec`** (*default: `clrDeepSkyBlue`*): Bullish decelerating bar color.
- **`InpColorBearExp`** (*default: `clrOrangeRed`*): Bearish expanding bar color.
- **`InpColorBearDec`** (*default: `clrCoral`*): Bearish decelerating bar color.
- **`InpHistWidth`** (*default: `2`*): Histogram bar thickness.

### === Visual Settings - Squeeze Dots ===

- **`InpColorSqzOff`** (*default: `clrLime`*): Zero-dot color when Squeeze has fired (OFF).

- **`InpColorSqzOn`** (*default: `clrRed`*): Zero-dot color when Squeeze is active (ON).
- **`InpDotSize`** (*default: `2`*): Thickness of the zero-line state dots.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                       TTM SQUEEZE PLAYBOOKS                            │
├────────────────────────────────────────────────────────────────────────┤
│ 1. The Squeeze Fired Breakout: Wait for >= 5 Red Dots -> Enter on 1st  │
│                                Lime Dot in direction of Momentum bar.  │
│ 2. Deceleration Exit Rule:     Hold position while LightSkyBlue/Orange │
│                                Red; exit/trail on 2nd Decelerating bar.│
│ 3. Head-Fake Shield:           If Squeeze fires but Momentum is flat   │
│                                near 0.0 -> Wait for decisive tilt.     │
│ 4. MTF Macro Volatility Sync:  Only trade M5 Squeeze breakouts that    │
│                                align with H1 Squeeze Momentum color.   │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: The Classical "Squeeze Fired" Breakout

- **Compression Phase:** Identify at least **5 to 8 consecutive Red Dots** along the zero line (`BufferSqueezeColors == 1.0`), indicating deep volatility coiling.

- **The Firing Trigger:** The very first candle that prints a **Lime Dot** (`BufferSqueezeColors == 0.0`).
- **Directional Filter:**
  - If Momentum histogram is **above zero and expanding (`clrLightSkyBlue`)** $\rightarrow$ Enter Long immediately.
  - If Momentum histogram is **below zero and expanding (`clrOrangeRed`)** $\rightarrow$ Enter Short immediately.
- **Protective Stop:** Placed on the opposite side of the 20 SMA basis or 1.5 ATR away.

### 6.2. Playbook 2: Momentum Deceleration Scaling & Trailing Exits

- **Mechanism:** Following a squeeze breakout, ride the move while bars remain `clrLightSkyBlue` (Long) or `clrOrangeRed` (Short).

- **Exit Signal:** When the histogram shifts color from LightSkyBlue to **`clrDeepSkyBlue`** (or OrangeRed to **`clrCoral`**) for two consecutive closed bars, acceleration has peaked. Scale out 50%–100% of the position before mean reversion begins.

### 6.3. Playbook 3: Multi-Timeframe Squeeze Alignment

- Attach an **H1-calculated Squeeze Pro** onto an **M5 execution chart**.

- **Quantitative Execution Rule:**
  $$\text{If } \text{BufferMom}_{\text{H1 Step}} > 0.0 \;\land\; \text{BufferMomColor}_{\text{H1 Step}} == 0.0 \implies \text{Long Breakouts Permitted Only}$$
- Prevents intraday scalpers from entering low-probability counter-trend fades during higher-timeframe squeeze expansions.

---

## 7. Indicator Buffer Map & Developer API

The indicator outputs its values through 4 native buffers, maintaining sub-millisecond execution speeds for Expert Advisors and multi-asset scanners.

### Output Buffer Indexing

| Buffer Index | Identifier | Buffer Type | Plot Role | Value Meaning |
| :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferMom` | `INDICATOR_DATA` | Histogram Height | TTM Linear Regression Momentum value |
| **1** | `BufferMomColor` | `INDICATOR_COLOR_INDEX` | Histogram Color | `0`=BullExp, `1`=BullDec, `2`=BearExp, `3`=BearDec |
| **2** | `BufferSqueeze` | `INDICATOR_DATA` | Dot Y-Coordinate | Anchored at `0.0` |
| **3** | `BufferSqueezeColors` | `INDICATOR_COLOR_INDEX` | Dot Color State | `0.0` = Lime (Squeeze Fired), `1.0` = Red (Squeeze ON) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the currently forming live bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet demonstrating how to automate Squeeze Pro signals in an Expert Advisor:

```mql5
//--- Create handle for Native or MTF Squeeze Pro
int handle = iCustom(_Symbol, _Period, "Squeeze_Pro",
                     PERIOD_CURRENT,         // InpTimeframe
                     20,                     // InpPeriod (BB & KC Basis)
                     2.0,                    // InpBBMult
                     14,                     // InpAtrPeriod (Independent ATR Period!)
                     1.5,                    // InpKCMult
                     ATR_SOURCE_STANDARD,    // InpAtrSource
                     PRICE_CLOSE_STD,        // InpSourcePrice
                     20                      // InpMomPeriod
                     // ... visual parameters fall back to defaults
                    );

if(handle == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create Squeeze_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) values (Bar 1 and Bar 2)
double mom_val[], mom_col[], sqz_col[];
ArraySetAsSeries(mom_val, true);
ArraySetAsSeries(mom_col, true);
ArraySetAsSeries(sqz_col, true);

if(CopyBuffer(handle, 0, 1, 2, mom_val) == 2 &&
   CopyBuffer(handle, 1, 1, 2, mom_col) == 2 &&
   CopyBuffer(handle, 3, 1, 2, sqz_col) == 2)
  {
   // Squeeze fired transition: Prior bar was Red (1.0), Closed bar is Lime (0.0)
   bool squeeze_just_fired = (sqz_col[1] == 1.0 && sqz_col[0] == 0.0);

   // Bullish Expanding Momentum (Positive & Color Index 0)
   bool bull_momentum = (mom_val[0] > 0.0 && mom_col[0] == 0.0);

   // Bearish Expanding Momentum (Negative & Color Index 2)
   bool bear_momentum = (mom_val[0] < 0.0 && mom_col[0] == 2.0);

   if(squeeze_just_fired && bull_momentum)
     {
      // Execute Buy Order (TTM Volatility Squeeze Breakout Long)
     }
   else if(squeeze_just_fired && bear_momentum)
     {
      // Execute Sell Order (TTM Volatility Squeeze Breakout Short)
     }
  }
```
