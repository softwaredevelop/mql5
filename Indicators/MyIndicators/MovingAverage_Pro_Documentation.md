# Universal Moving Average (Moving Average) Pro (v3.20)

## Institutional Quantitative Smoothing Engine & Modular Multi-Algorithm Moving Average Suite

>*Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Summary & System Overview

**Moving Average Pro** is the institutional baseline trend overlay and dynamic digital signal processing (DSP) suite of the Professional MQL5 Suite. Operating on the modernized **v3.20 Enterprise Modular Architecture**, it decouples mathematical smoothing kernels into independent, pluggable strategy classes via `MA_CoreCalculators.mqh`, unified through the backward-compatible facade engine `MovingAverage_Engine.mqh`.

Moving averages form the core infrastructure for trend identification, dynamic support/resistance, volatility band centering, and signal line derivation. **Moving Average Pro provides instant algorithm interchangeability without altering indicator pipelines, buffer layouts, or chart setups**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   THE 8 MOVING AVERAGE ALGORITHMS                      │
├───────┬────────────────────────┬───────┬───────────────────────────────┤
│ Type  │ Full Mathematical Name │ Type  │ Full Mathematical Name        │
├───────┼────────────────────────┼───────┼───────────────────────────────┤
│ SMA   │ Simple Moving Average  │ TMA   │ Triangular Moving Average     │
│ EMA   │ Exponential Moving Avg │ DEMA  │ Double Exponential Moving Avg │
│ SMMA  │ Smoothed MA (Wilder)   │ TEMA  │ Triple Exponential Moving Avg │
│ LWMA  │ Linear Weighted MA     │ VWMA  │ Volume-Weighted Moving Avg    │
└───────┴────────────────────────┴───────┴───────────────────────────────┘
```

### Key Architectural Capabilities

- **Decoupled Strategy Pattern:** Moving average algorithms operate as autonomous calculator classes inheriting from `CBaseMACalculator`, isolating memory footprints and eliminating cross-algorithm bugs.
- **Zero-Waste Dynamic Memory:** Single-pass algorithms (SMA, EMA, SMMA, LWMA, VWMA) allocate zero auxiliary scratchpads, while multi-stage cascades (TMA, DEMA, TEMA) manage private, isolated state registers.
- **ALU-Optimized Execution:** Division operations are replaced with precomputed reciprocal multiplications ($1.0 / P$), and Linear Weighted MA utilizes Gauss's closed-form sum of weights ($\frac{P(P+1)}{2}$) to eliminate inner-loop accumulators.
- **Full Volume Routing (VWMA):** Automatic runtime arbitration queries broker `SYMBOL_VOLUME_LIMIT` to pipe Real Volume (`VOLUME_REAL`) on exchange assets or Tick Volume (`VOLUME_TICK`) on CFD instruments.
- **Unified MTF Fast-Path Pipeline:** Maps higher-timeframe baselines (e.g., H1, H4, D1) onto lower-timeframe execution charts (M1, M5, M15) using a Two-Pointer Chronological Sweep and zero-API RAM mocking on live ticks.
- **Synthetic Heikin Ashi Pipeline:** Seamlessly computes smoothed curves from synthetic Heikin Ashi price series via specialized polymorphic inheritance (`CMovingAverageCalculator_HA`).
- **Strict Non-Repainting & Thread Safety:** Guaranteed closed-bar immutability, zero static array caches in member functions, and strict chronological series indexing (`ArraySetAsSeries(..., false)`).

---

## 2. Mathematical Foundations & The 8 Smoothing Models

```text
                  RAW INPUT SERIES: Close, Median, Typical, HA Close
                                           │
       ┌───────────────┬───────────────────┼───────────────────┬───────────────┐
       ▼               ▼                   ▼                   ▼               ▼
   Linear        Exponential           Double/Triple       Triangular       Volume-Weighted
  (SMA/LWMA)     (EMA/SMMA)            (DEMA/TEMA)           (TMA)              (VWMA)
```

### 2.1. Simple Moving Average (SMA)

Arithmetic mean of the previous $P = \text{InpPeriod}$ bars:
$$\text{SMA}_t = \left(\sum_{j=0}^{P-1} P_{t-j}\right) \times \frac{1}{P}$$
*ALU Optimization:* The division by $P$ is hoisted and executed via a single multiplication by `m_inv_period`.

---

### 2.2. Exponential Moving Average (EMA)

First-order recursive Infinite Impulse Response (IIR) filter:
$$\alpha = \frac{2}{P + 1}, \quad\quad \beta = 1.0 - \alpha$$
$$\text{EMA}_t = P_t \cdot \alpha + \text{EMA}_{t-1} \cdot \beta$$
*Initial Seeding:* The base anchor at bar $P-1$ is initialized using an SMA over the initial $P$ bars. Recursive states are strictly preserved on live tick updates.

---

### 2.3. Smoothed Moving Average (SMMA / Wilder's RMA)

J. Welles Wilder Jr.'s recursive smoothing filter (mathematically equivalent to an EMA with $\alpha = 1/P$):
$$\text{SMMA}_t = \frac{\text{SMMA}_{t-1} \cdot (P - 1) + P_t}{P} = \left(\text{SMMA}_{t-1} \cdot (P - 1) + P_t\right) \times \frac{1}{P}$$

---

### 2.4. Linear Weighted Moving Average (LWMA)

Weights prices linearly proportional to their temporal recency ($W_j = P - j$).
The sum of arithmetic weights is computed analytically using Gauss's closed-form equation, avoiding runtime inner-loop accumulation:
$$\sum_{j=0}^{P-1} (P - j) = \frac{P(P + 1)}{2}$$
$$\text{LWMA}_t = \left(\sum_{j=0}^{P-1} P_{t-j} \cdot (P - j)\right) \times \frac{1}{\frac{P(P + 1)}{2}}$$

---

### 2.5. Triangular Moving Average (TMA)

Double-smoothed simple moving average producing a triangular-shaped convolution kernel that aggressively suppresses high-frequency spectral noise:
$$P_1 = \left\lceil \frac{P + 1}{2} \right\rceil, \quad\quad P_2 = P - P_1 + 1$$
$$\text{Stage 1: } S_t = \text{SMA}(P_t, P_1), \quad\quad \text{TMA}_t = \text{SMA}(S_t, P_2)$$
*Pipelined Lookback:* Stage 1 updates across an extended historical lookback window ($P_2 + 1$ bars deeper than the recalculation index) to ensure Stage 2 never reads stale intermediate states during live ticks.

---

### 2.6. Double Exponential Moving Average (DEMA - Patrick Mulloy)

Eliminates first-order exponential phase lag by combining single and cascaded double EMAs:
$$\text{EMA1}_t = \text{EMA}(P, P), \quad\quad \text{EMA2}_t = \text{EMA}(\text{EMA1}, P)$$
$$\text{DEMA}_t = 2 \cdot \text{EMA1}_t - \text{EMA2}_t$$

---

### 2.7. Triple Exponential Moving Average (TEMA - Patrick Mulloy)

Eliminates first- and second-order exponential phase lag for near-zero phase latency:
$$\text{EMA1}_t = \text{EMA}(P, P), \quad \text{EMA2}_t = \text{EMA}(\text{EMA1}, P), \quad \text{EMA3}_t = \text{EMA}(\text{EMA2}, P)$$
$$\text{TEMA}_t = 3 \cdot \text{EMA1}_t - 3 \cdot \text{EMA2}_t + \text{EMA3}_t$$

---

### 2.8. Volume-Weighted Moving Average (VWMA)

Weights price bars directly proportional to transacted trading volume ($V_t$):
$$\text{VWMA}_t = \frac{\sum_{j=0}^{P-1} P_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{P-1} V_{t-j}}$$
*Zero-Volume Fallback:* If trading volume is zero or unavailable, volume weights default to $1.0$, collapsing gracefully into a standard SMA.

---

### 2.9. DSP Filtering Characteristics & Performance Matrix

| Algorithm | Smoothness | Phase Latency (Lag) | Noise Resistance | Optimal Quantitative Market Context |
| :--- | :---: | :---: | :---: | :--- |
| **SMA** | Medium | High | High | Long-term macro benchmarks (e.g., 50/200 Day benchmarks). |
| **EMA** | High | Medium | Medium | Classical trend-following, dynamic envelopes, and MACD derivation. |
| **SMMA** | Very High | High | Very High | Wilder-style indicators (RSI, ADX, ATR, Volatility Bands). |
| **LWMA** | Medium | Low | Low | Short-term momentum tracking, fast directional scalping. |
| **TMA** | Ultra-High | Very High | Ultra-High | Dominant cycle wave extraction; complete elimination of market ripples. |
| **DEMA** | Medium | Very Low | Low | Intermediate swing systems; eliminates ~50% of classical EMA phase lag. |
| **TEMA** | Low | Near-Zero | Very Low | High-frequency microstructure tracking; instant reaction to price impulses. |
| **VWMA** | High | Dynamic | High | Institutional liquidity analysis; volume-confirmed breakout validation. |

---

## 3. Enterprise Modular Architecture (Strategy & Facade Pattern)

Version 3.20 replaces the monolithic engine with a clean **Gang of Four (GoF) Strategy & Facade** design pattern:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   MovingAverage_Pro.mq5 (Wrapper)                      │
│   • Input validation, Chart Plot Bindings, Dynamic DrawBegin           │
│   • Two-Pointer MTF Synchronization Daemon & Binary Fast-Path          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Instantiates & Calls
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             MovingAverage_Engine.mqh (Facade & Router)                 │
│   • CMovingAverageCalculator / CMovingAverageCalculator_HA             │
│   • 100% Backward-Compatible Interface (Preserved Methods & Enums)     │
│   • Manages Persistent Working Buffers (m_price[], m_volume[])         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Delegates to Strategy (Polymorphism)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                  MA_CoreCalculators.mqh (Strategies)                   │
│   • Abstract Base: CBaseMACalculator                                   │
│   ├─ CSMACalculator      (Simple Moving Average)                       │
│   ├─ CEMACalculator      (Exponential Moving Average)                  │
│   ├─ CSMMACalculator     (Smoothed Moving Average)                     │
│   ├─ CLWMACalculator     (Linear Weighted Moving Average)              │
│   ├─ CTMACalculator      (Triangular MA - Manages m_stage1_buffer[])   │
│   ├─ CDEMACalculator     (Double EMA - Manages m_ema1[], m_ema2[])     │
│   ├─ CTEMACalculator     (Triple EMA - Manages m_ema1..3[])            │
│   └─ CVWMACalculator     (Volume-Weighted Moving Average)              │
└────────────────────────────────────────────────────────────────────────┘
```

### Architectural Benefits

1. **Open/Closed Principle (OCP):** New algorithms can be integrated without modifying or destabilizing existing calculations.
2. **Encapsulated State Registers:** Intermediate buffers for multi-stage algorithms (such as `m_ema1_buffer`, `m_ema2_buffer`, and `m_stage1_buffer`) are declared inside their respective classes. Algorithms like SMA or EMA never allocate unnecessary buffers in memory.
3. **100% Drop-In Compatibility:** Other indicators in your suite (`MACD_Pro`, `BollingerBands_Pro`, `Keltner_Pro`, etc.) using `CMovingAverageCalculator` require **zero modifications** to take advantage of the upgraded performance.

---

## 4. Developer Extensibility Guide: Adding a New MA Algorithm

Adding a new moving average algorithm (e.g., **Hull Moving Average - HMA**) requires only three clean steps:

### Step 1: Implement the Algorithm Class in `MA_CoreCalculators.mqh`

Create a new class inheriting from `CBaseMACalculator`:

```mql5
//+------------------------------------------------------------------+
//| CLASS: CHMACalculator (Hull Moving Average)                      |
//+------------------------------------------------------------------+
class CHMACalculator : public CBaseMACalculator
  {
private:
   CLWMACalculator   m_lwma_half;
   CLWMACalculator   m_lwma_full;
   CLWMACalculator   m_lwma_final;
   double            m_diff_buffer[];

public:
   virtual bool Init(const int period) override
     {
      if(!CBaseMACalculator::Init(period)) return false;
      int half_p  = MathMax(1, (int)MathFloor(m_period * 0.5));
      int sqrt_p  = MathMax(1, (int)MathFloor(MathSqrt(m_period)));
      m_lwma_half.Init(half_p);
      m_lwma_full.Init(m_period);
      m_lwma_final.Init(sqrt_p);
      return true;
     }

   virtual void Calculate(const int rates_total, const int start_index,
                          const double &price[], const double &volume[],
                          double &output[], const int data_offset = 0) override
     {
      // ... HMA calculation logic using the sub-calculators ...
     }

   virtual int GetWarmupBars(void) const override { return m_period + (int)MathSqrt(m_period); }
  };
```

### Step 2: Register in `ENUM_MA_TYPE`

Add the new type identifier to `ENUM_MA_TYPE` in `MovingAverage_Engine.mqh`:

```mql5
enum ENUM_MA_TYPE
  {
   SMA,
   EMA,
   SMMA,
   LWMA,
   TMA,
   DEMA,
   TEMA,
   VWMA,
   HMA  // <-- New Algorithm Registered
  };
```

### Step 3: Wire into the Factory Method

Add one case to `CMovingAverageCalculator::CreateAlgorithm` in `MovingAverage_Engine.mqh`:

```mql5
case HMA: m_algo = new CHMACalculator(); break;
```

*The indicator wrapper, MTF framework, and all dependent indicators will immediately recognize and execute the new algorithm with full MTF and Heikin Ashi support!*

---

## 5. Multi-Timeframe (MTF) Two-Pointer Fast-Path Protocol

When `InpTimeframe > Period()`, the indicator activates the institutional Fast-Path MTF engine:

```text
  HTF Time Domain (e.g. H1)
  [ HTF Bar 0 ]------------------------>[ HTF Bar 1 ]------------------------>[ HTF Forming ]
        │                                     │                                     │
        ▼ (Chronological 2-Pointer Projection)▼                                     ▼
  LTF Time Domain (e.g. M5)
  [m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5]
  └───────────────────┘ └───────────────────┘ └───────────────────┘ └───────────────────────┘
     Flat Step 0           Flat Step 1           Flat Step 2           Forming Block (Live)
```

1. **Atomic Bulk Rates Acquisition:** When an HTF bar closes or on cold start, a single `CopyRates()` query synchronizes OHLCV into chronological caches (`h_open`, `h_high`, `h_low`, `h_close`, `h_vol`).
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Maps HTF computed values onto LTF chart bars in a single forward pass without calling `iBarShift()`:

   ```mql5
   int htf_ptr = 0;
   for(int i = 0; i < rates_total; i++)
     {
      while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= time[i])
         htf_ptr++;
      BufferMA[i] = h_res_ma[htf_ptr];
     }
   ```

3. **Live Tick RAM Mocking & Binary Snapping:** On ticks that occur while the HTF candle is still forming, only the last bar in RAM (`h_close[live_idx]`) is refreshed, and a localized calculation evaluates the forming candle. An $O(\log N)$ binary search (`ArrayBsearch`) locates the first LTF bar belonging to the forming HTF block and updates the values across the forming block in nanoseconds.

---

## 6. Parameters & Configuration Reference

### Timeframe Settings

- **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Timeframe of calculation. Set to `PERIOD_CURRENT` for standard native operation, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`) to project a synchronized staircase MTF baseline. Target timeframe must be $\ge$ chart timeframe.

### Moving Average Core Settings

- **`InpPeriod`** (*default: `20`*): The lookback smoothing window ($P$). Must be an integer $\ge 1$.

- **`InpMAType`** (*default: `SMA`*): Mathematical smoothing algorithm selection:
  - `SMA`: Simple Moving Average
  - `EMA`: Exponential Moving Average
  - `SMMA`: Smoothed Moving Average (Wilder's RMA)
  - `LWMA`: Linear Weighted Moving Average
  - `TMA`: Triangular Moving Average
  - `DEMA`: Double Exponential Moving Average
  - `TEMA`: Triple Exponential Moving Average
  - `VWMA`: Volume-Weighted Moving Average
- **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price source. Supports all 7 standard Applied Price modes (`PRICE_CLOSE_STD` through `PRICE_WEIGHTED_STD`) and 7 synthetic Heikin Ashi modes (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### Visual Settings

- **`InpColorMA`** (*default: `clrDodgerBlue`*): Primary plot line color.

- **`InpStyleMA`** (*default: `STYLE_SOLID`*): Plot line style (`STYLE_SOLID`, `STYLE_DASH`, `STYLE_DOT`, `STYLE_DASHDOT`).
- **`InpWidthMA`** (*default: `2`*): Plot line width in pixels.

---

## 7. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   MOVING AVERAGE TRADING PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Dynamic Baseline Retest: Pullbacks to rising EMA/VWMA offer low-risk│
│                             continuation entries in strong trends.     │
│ 2. Institutional Cross:     50 EMA crossing above 200 SMA confirms a   │
│                             macro Golden Cross regime shift.           │
│ 3. MTF Macro Step Filter:   Only execute M5 long setups when price is  │
│                             trading above the H1 50 EMA flat step.     │
└────────────────────────────────────────────────────────────────────────┘
```

### 7.1. Dynamic Support & Resistance Pullbacks

- **Bullish Setup:** Market is in an established uptrend above a rising **`20 EMA`** or **`20 VWMA`**. When price retraces toward the dynamic line and prints a rejection candle with a lower wick $\rightarrow$ Long continuation trigger.

- **Bearish Setup:** Market is in a downtrend below a falling moving average. Price rallies to test the line from underneath and prints an upper rejection wick $\rightarrow$ Short continuation trigger.

### 7.2. Golden Cross & Death Cross Regime Shifts

- **Golden Cross (Macro Expansion):** A fast moving average (e.g., `50 EMA`) crosses **above** a slower baseline (e.g., `200 SMA`) with rising trading volume $\rightarrow$ Transition into a macro bull market regime.

- **Death Cross (Macro Contraction):** The fast moving average crosses **below** the slower baseline $\rightarrow$ Transition into a macro bear market regime.

### 7.3. Multi-Timeframe Macro Step Alignment

- Attach an **H1-calculated 50 EMA** onto an **M5 execution chart**.

- **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferMA}_{\text{H1 Step}} \implies \text{Long Orders Allowed Only}$$
  $$\text{If } \text{Bid} < \text{BufferMA}_{\text{H1 Step}} \implies \text{Short Orders Allowed Only}$$
- Eliminates counter-trend scalping against institutional macro order flow.

---

## 8. Indicator Buffer Map & Developer API

### Indicator Output Buffers

| Buffer Index | Identifier | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferMA` | `INDICATOR_DATA` | Universal Moving Average value line |

*Buffer indexing strictly enforces chronological ordering (`ArraySetAsSeries = false`), where index `0` represents the oldest bar in history and index `rates_total - 1` represents the currently forming bar.*

### Expert Advisor / Scanner Integration (`iCustom`)

To call `MovingAverage_Pro` from an Expert Advisor or custom multi-asset dashboard:

```mql5
//--- Create indicator handle
int handle = iCustom(_Symbol, _Period, "MovingAverage_Pro",
                     PERIOD_CURRENT,     // InpTimeframe
                     20,                 // InpPeriod
                     EMA,                // InpMAType (ENUM_MA_TYPE)
                     PRICE_CLOSE_STD,    // InpSourcePrice (ENUM_APPLIED_PRICE_HA_ALL)
                     clrDodgerBlue,      // InpColorMA
                     STYLE_SOLID,        // InpStyleMA
                     2);                 // InpWidthMA

if(handle == INVALID_HANDLE)
  {
   Print("Error: Failed to create MovingAverage_Pro handle.");
   return;
  }

//--- Read the latest finalized (closed bar) value
double ma_values[];
ArraySetAsSeries(ma_values, true); // Use series indexing for convenient [1] access

if(CopyBuffer(handle, 0, 1, 1, ma_values) == 1)
  {
   double closed_ma = ma_values[0]; // Value at bar 1 (Closed bar)
   // Execute trading logic...
  }
```
