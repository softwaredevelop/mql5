# Heikin Ashi Pro (v4.00)

Ultra-Low Latency Synthetic Candlestick Stream & Trend-Filtering Engine

---

## 1. Summary (Introduction)

**Heikin Ashi Pro** is an institutional-grade chart overlay indicator designed to eliminate market microstructure noise, false breakouts, and high-frequency erratic price spikes by synthesizing modified volume-neutral candlesticks.

In high-density algorithmic trading workspaces—where traders frequently operate **13 to 14 active chart windows simultaneously**, with over 10 indicators per window—standard Heikin Ashi implementations cause severe **UI Thread Saturation and tick-lag**. This latency causes chart candles to freeze momentarily before suddenly jumping to catch up with Market Watch ticks.

**Heikin Ashi Pro (v4.00)** introduces an **Enterprise Fused $O(1)$ Architecture**:

1. Eliminates legacy hidden buffer overhead, reducing memory footprint by **45%**.
2. Fuses candlestick math and directional color mapping into a **single-pass vectorized execution loop**.
3. Completely frees the MetaTrader 5 DirectX rendering pipeline, guaranteeing instant, freeze-free chart refreshes across massive multi-chart setups.

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   HEIKIN ASHI ARCHITECTURAL EVOLUTION                  │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   LEGACY MODEL (v3.05):                                                │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ 9 Buffers (4 HA + 1 Color + 4 Dummy OHLC)                    │     │
│   │ 3 Separate Iterative Loops per incoming tick                 │     │
│   │ 56 Redundant Dynamic Double Arrays across 14 charts          │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                  │                                     │
│                                  ▼ OPTIMIZED                           │
│   ENTERPRISE MODEL (v4.00):                                            │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │ 5 Buffers (4 HA + 1 Color) — Zero Dummy Arrays               │     │
│   │ 1 Fused Vectorized Loop Pass (Multiplication Kernel)         │     │
│   │ Zero Dynamic Heap Allocations (Static BSS Instantiation)     │     │
│   └──────────────────────────────────────────────────────────────┘     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘

```

### Key Architectural Highlights

- **45% Immediate Memory Reduction:** Buffers reduced from 9 to 5, eliminating 56 unused dynamic array allocations across a 14-chart workspace.
- **Single-Pass Fused Execution Loop:** Calculates HA Open, Close, High, Low, and Color Index within the same memory cache line in $O(1)$ incremental time.
- **SIMD-Pipelined Math:** Replaces slow floating-point divisions (`/ 4.0`, `/ 2.0`) with fast scalar multiplications (`* 0.25`, `* 0.5`).
- **Zero-Heap BSS Instantiation:** Eliminates runtime pointer allocation (`new`/`delete`), eliminating heap fragmentation and GC latency.
- **100% Backward-Compatible Engine:** Enhances `HeikinAshi_Tools.mqh` with a fused 11-parameter overload while preserving the legacy 10-parameter interface used by VWAP, RV-Score, and Moving Average engines.

---

## 2. Mathematical Foundations & Vectorized Smoothing

```text

                          Real Bar (t)                     HA Synthetic Bar (t)
                       ┌────────────────┐                   ┌────────────────┐
                       │      High      │                   │    HA High     │
                       │   ┌────────┐   │                   │   ┌────────┐   │
                       │   │  Open  │   │                   │   │HA Close│   │
                       │   │        │   │ ───────────────▶  │   │        │   │
                       │   │ Close  │   │                   │   │HA Open │   │
                       │   └────────┘   │                   │   └────────┘   │
                       │      Low       │                   │     HA Low     │
                       └────────────────┘                   └────────────────┘

```

### 2.1. Synthetic Heikin Ashi Close ($\text{HA\_Close}_t$)

The synthetic close is the arithmetic mean of the real bar's four core price components:
$$\text{HA\_Close}_t = \frac{\text{Open}_t + \text{High}_t + \text{Low}_t + \text{Close}_t}{4} = (\text{Open}_t + \text{High}_t + \text{Low}_t + \text{Close}_t) \cdot 0.25$$

### 2.2. Recursive Synthetic Heikin Ashi Open ($\text{HA\_Open}_t$)

The synthetic open is the midpoint of the *previous* Heikin Ashi candle, establishing recursive inertia:
$$\text{HA\_Open}_0 = (\text{Open}_0 + \text{Close}_0) \cdot 0.5$$
$$\text{HA\_Open}_t = (\text{HA\_Open}_{t-1} + \text{HA\_Close}_{t-1}) \cdot 0.5 \quad \text{for } t \ge 1$$

### 2.3. Synthetic Extreme Boundaries ($\text{HA\_High}_t$, $\text{HA\_Low}_t$)

$$\text{HA\_High}_t = \max \Big( \text{High}_t, \; \max(\text{HA\_Open}_t, \; \text{HA\_Close}_t) \Big)$$
$$\text{HA\_Low}_t  = \min \Big( \text{Low}_t,  \; \min(\text{HA\_Open}_t, \; \text{HA\_Close}_t) \Big)$$

---

### 2.4. Directional Color Indexing ($\text{HA\_Color}_t$)

$$\text{HA\_Color}_t = \begin{cases} 0.0 \; (\text{Bullish } \rightarrow \text{clrCornflowerBlue}), & \text{if } \text{HA\_Close}_t \ge \text{HA\_Open}_t \\ 1.0 \; (\text{Bearish } \rightarrow \text{clrChocolate}), & \text{if } \text{HA\_Close}_t < \text{HA\_Open}_t \end{cases}$$

---

### 2.5. Mathematical Proof of Price Scale Encompassment

*Why the 4 legacy dummy OHLC buffers (`DRAW_NONE`) were redundant:*

1. By mathematical definition:
   $$\text{HA\_High}_t = \max(\text{High}_t, \dots) \implies \text{HA\_High}_t \ge \text{High}_t$$
   $$\text{HA\_Low}_t  = \min(\text{Low}_t,  \dots) \implies \text{HA\_Low}_t  \le \text{Low}_t$$
2. Consequently, the synthetic Heikin Ashi candle **strictly covers or exceeds** the vertical price extremes of the underlying asset:
   $$[\text{Low}_t, \; \text{High}_t] \subseteq [\text{HA\_Low}_t, \; \text{HA\_High}_t]$$
3. The MetaTrader 5 vertical autoscaling engine derives chart boundaries exclusively from visible plotting geometry (`DRAW_COLOR_CANDLES`). Dummy `DRAW_NONE` buffers never participated in autoscaling. Removing them causes zero scaling degradation while freeing massive memory blocks.

---

## 3. MQL5 Architecture & Computational Benchmarking

```text

┌────────────────────────────────────────────────────────┐
│                 HeikinAshi_Tools.mqh                   │
│   (Fused Single-Pass SIMD Kernel: O(1) Vectorized)     │
└──────────────────────────┬─────────────────────────────┘
                           │ Outputs HA OHLC + Color in 1 Pass
                           ▼
┌────────────────────────────────────────────────────────┐
│                 Chart_HeikinAshi.mq5                   │
│       (Thin GUI Overlay Wrapper: 5 Buffers Only)       │
├────────────────────────────────────────────────────────┤
│   Buffer Layout (5)                                    │
│   • Buffer 0: BufferHA_Open   (INDICATOR_DATA)         │
│   • Buffer 1: BufferHA_High   (INDICATOR_DATA)         │
│   • Buffer 2: BufferHA_Low    (INDICATOR_DATA)         │
│   • Buffer 3: BufferHA_Close  (INDICATOR_DATA)         │
│   • Buffer 4: BufferColor     (INDICATOR_COLOR_INDEX)  │
└────────────────────────────────────────────────────────┘

```

### Engineering Benchmark: Legacy (v3.05) vs. Enterprise (v4.00)

| Metric | Legacy Implementation (v3.05) | Enterprise Refactor (v4.00) | Net Optimization |
| :--- | :---: | :---: | :---: |
| **Allocated Buffers** | 9 Buffers | **5 Buffers** | **-44.4% Memory Footprint** |
| **Active Plot Types** | 2 (`DRAW_COLOR_CANDLES`, `DRAW_NONE`) | **1 (`DRAW_COLOR_CANDLES`)** | **-50.0% Drawing Calls** |
| **Loops per Tick** | 3 Independent For-Loops | **1 Fused Vectorized Loop** | **-66.7% Iteration Overhead** |
| **Division Operations** | 2 Divisions (`/ 4.0`, `/ 2.0`) | **0 Divisions (`* 0.25`, `* 0.5`)** | **Hardware SIMD Pipelining** |
| **Dynamic Allocations** | `new CHeikinAshi_Calculator()` | **Static BSS Global Object** | **Zero Heap Fragmentation** |
| **Workspace Overhead (14 Charts)** | 126 Dynamic Array Buffers | **70 Dynamic Array Buffers** | **56 Dynamic Buffers Eliminated** |

---

## 4. Parameters Reference & Visual Palette

### Inputs Reference

`Chart_HeikinAshi.mq5` features a **zero-parameter input signature**, ensuring instant attachment without dialog prompts:

- **Calculation Mode:** Native $O(1)$ standard (only re-evaluates bar `rates_total - 1` on live incoming ticks).
- **Array Indexing:** Chronological non-series order (`ArraySetAsSeries = false`), maintaining array index `0` as oldest historic bar.

### Visual Styling Palette

| State | Plot Color | Color Name | Default Style | Visual Meaning |
| :---: | :---: | :--- | :---: | :--- |
| **Color Index 0** | `clrCornflowerBlue` | Cornflower Blue | `STYLE_SOLID` | **Bullish Trend Regime:** Synthetic close $\ge$ open. |
| **Color Index 1** | `clrChocolate` | Chocolate / Rust Orange | `STYLE_SOLID` | **Bearish Trend Regime:** Synthetic close $<$ open. |

*Recommended Chart Setup:* To prevent visual overlap with default MT5 black-and-white candlesticks, navigate to `Chart Properties (F8) -> Common -> Chart Mode -> Line Chart`, and set the line chart color to `None` in the `Colors` tab.

---

## 5. Quantitative Trading Playbooks

```text

┌────────────────────────────────────────────────────────────────────────┐
│                   HEIKIN ASHI QUANTITATIVE PLAYBOOKS                   │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Flat-Base Momentum Expansion:  Zero lower wick in bull trend;       │
│                                   zero upper wick in bear trend.       │
│ 2. Trend Persistence Filter:      Hold positions as long as candle     │
│                                   color remains strictly unchanged.    │
│ 3. Wicking Exhaustion Warning:    Emergence of opposing wicks signals  │
│                                   momentum deceleration.               │
└────────────────────────────────────────────────────────────────────────┘

```

### 5.1. Flat-Base Momentum Expansion (Institutional Trend Drive)

- **Bullish Expansion Rule:**
  - A series of `clrCornflowerBlue` candles print with **no lower wick** ($\text{HA\_Open}_t \approx \text{HA\_Low}_t$).
  - **Meaning:** Aggressive directional buying without intraday pullback below the open.
  - **Execution:** Maintain aggressive trend-following long exposure; advance trailing stop behind the previous HA Low.
- **Bearish Markdown Rule:**
  - A series of `clrChocolate` candles print with **no upper wick** ($\text{HA\_Open}_t \approx \text{HA\_High}_t$).
  - **Meaning:** Aggressive institutional distribution without intraday bounce above the open.
  - **Execution:** Maintain short trend-following exposure.

### 5.2. Double-Wicked Indecision & Exhaustion Alert

- **Context:** A persistent bull run prints large `clrCornflowerBlue` candles with flat bottoms. Suddenly, a candle prints with **long upper and lower wicks**, accompanied by a shrinking synthetic real body ($|\text{HA\_Close} - \text{HA\_Open}| \to 0$).
- **Meaning:** Equilibrium re-established; directional conviction exhausted.
- **Action:** Scale out 50–75% of trend positions; prepare for consolidation or mean reversion to the Rolling VWAP.

---

## 6. Indicator Buffer Map (For Developers & EA Integration)

### Buffer Allocation

| Buffer Index | Name | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferHA_Open` | `INDICATOR_DATA` | Synthetic Heikin Ashi Open price series. |
| **1** | `BufferHA_High` | `INDICATOR_DATA` | Synthetic Heikin Ashi High price series. |
| **2** | `BufferHA_Low` | `INDICATOR_DATA` | Synthetic Heikin Ashi Low price series. |
| **3** | `BufferHA_Close` | `INDICATOR_DATA` | Synthetic Heikin Ashi Close price series. |
| **4** | `BufferColor` | `INDICATOR_COLOR_INDEX` | Binary Directional Color Index (`0.0` = Bullish, `1.0` = Bearish). |

*All buffers maintain strict chronological indexing (`ArraySetAsSeries = false`), ensuring seamless integration in automated Expert Advisors via `iCustom()`.*

---

### MQL5 EA Integration Interface Template

```mql5
//+------------------------------------------------------------------+
//|                                     EA_HeikinAshi_Interface.mq5  |
//|                                          Copyright 2026, xxxxxxxx|
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, xxxxxxxx"
#property version   "1.00"
#property strict

//--- Global Indicator Handle
int g_ha_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(g_ha_handle != INVALID_HANDLE)
      IndicatorRelease(g_ha_handle);

   // Instantiate handle to Chart_HeikinAshi via iCustom
   g_ha_handle = iCustom(_Symbol, _Period, "Chart_HeikinAshi");

   if(g_ha_handle == INVALID_HANDLE)
     {
      PrintFormat("EA Error: Failed to create handle for Chart_HeikinAshi. Error: %d", GetLastError());
      return INIT_FAILED;
     }

   Print("EA Success: Chart_HeikinAshi handle initialized successfully.");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_ha_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_ha_handle);
      g_ha_handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Query completed closed candle (Shift = 1) across all HA buffers
   double ha_open[1], ha_high[1], ha_low[1], ha_close[1], ha_color[1];

   if(CopyBuffer(g_ha_handle, 0, 1, 1, ha_open)  < 1 ||
      CopyBuffer(g_ha_handle, 1, 1, 1, ha_high)  < 1 ||
      CopyBuffer(g_ha_handle, 2, 1, 1, ha_low)   < 1 ||
      CopyBuffer(g_ha_handle, 3, 1, 1, ha_close) < 1 ||
      CopyBuffer(g_ha_handle, 4, 1, 1, ha_color) < 1)
     {
      return;
     }

   double o = ha_open[0];
   double h = ha_high[0];
   double l = ha_low[0];
   double c = ha_close[0];
   int  col = (int)ha_color[0];

   // Quantitative Signals
   bool is_bullish = (col == 0); // CornflowerBlue
   bool is_bearish = (col == 1); // Chocolate

   // Flat-base institutional momentum confirmation
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0) tick_size = _Point;

   bool is_flat_bottom = MathAbs(o - l) <= tick_size * 0.5; // No lower wick
   bool is_flat_top    = MathAbs(o - h) <= tick_size * 0.5; // No upper wick

   // Telemetry Output
   Comment(StringFormat("Heikin Ashi Telemetry [Bar 1]:\n"
                        "HA Open: %.*f | High: %.*f | Low: %.*f | Close: %.*f\n"
                        "Trend Regime: %s | Flat-Drive: %s",
                        _Digits, o, _Digits, h, _Digits, l, _Digits, c,
                        is_bullish ? "BULLISH FLOW" : "BEARISH FLOW",
                        (is_bullish && is_flat_bottom) ? "STRONG BULL DRIVE" :
                        ((is_bearish && is_flat_top)    ? "STRONG BEAR DRIVE" : "NORMAL")));
  }
//+------------------------------------------------------------------+
```
