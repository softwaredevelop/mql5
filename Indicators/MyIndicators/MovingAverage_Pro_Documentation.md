# Universal Moving Average (Moving Average) Pro (v3.60)

## Component-Based Quantitative DSP Engine & Micro-Kernel Architecture Specification

**Enterprise Ultra Edition — High-Concurrency DSP Engine for MetaTrader 5*

---

## 1. Executive Summary & System Overview

**Moving Average Pro (v3.60)** is the institutional trend overlay and digital signal processing (DSP) baseline of the Professional MQL5 Suite. Operating on a **Component-Based Micro-Kernel Architecture**, the suite completely decouples distinct moving average mathematical smoothing engines into independent, isolated calculation modules housed in `MQL5\Include\MyIncludes\MACalculators\`.

Moving averages serve as the foundational bedrock for algorithmic trend identification, dynamic support/resistance channels, volatility band centering, and higher-timeframe macro filters. **Moving Average Pro provides instant algorithm interchangeability across 9 production-validated, mathematically verified smoothing models**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│               THE 9 PRODUCTION-VALIDATED ALGORITHMS                    │
├───────┬────────────────────────┬───────┬───────────────────────────────┤
│ Type  │ Full Mathematical Name │ Type  │ Full Mathematical Name        │
├───────┼────────────────────────┼───────┼───────────────────────────────┤
│ SMA   │ Simple Moving Average  │ TMA   │ Triangular Moving Average     │
│ EMA   │ Exponential Moving Avg │ DEMA  │ Double Exponential Moving Avg │
│ SMMA  │ Smoothed MA (Wilder)   │ TEMA  │ Triple Exponential Moving Avg │
│ LWMA  │ Linear Weighted MA     │ VWMA  │ Volume-Weighted Moving Avg    │
│ HMA   │ Hull Moving Average    │       │                               │
└───────┴────────────────────────┴───────┴───────────────────────────────┘
```

---

## 2. Architectural Manifesto: Why This Structure Was Built

Understanding the architectural history and design rationale is mandatory for future developers maintaining, expanding, and refining this quantitative library.

### 2.1. The Failure of the Monolithic Approach (v1.x – v2.x)

In earlier versions, all moving average algorithms were embedded inside a single, monolithic `MovingAverage_Engine.mqh` file using a centralized `switch(m_ma_type)` statement:

- **High Blast Radius:** Modifying or debugging an experimental moving average (such as McGinley Dynamic or ZLEMA) required editing the exact same file that calculated critical production SMA and EMA filters. A typo, uninitialized variable, or compile warning broke the entire quantitative suite.
- **Memory Bloating:** Every instance of the engine allocated auxiliary dynamic arrays (`m_temp_buffer1`, `m_temp_buffer2`, `m_temp_buffer3`) on the heap, forcing lightweight calculations (like SMA) to carry the memory footprint of heavy cascaded models (like TEMA).
- **Violated Open/Closed Principle (OCP):** The software was not closed for modification when extending functionality.

### 2.2. The Intermediate Phase: Single-File Strategy Pattern (v3.0 – v3.5)

The introduction of an abstract strategy class (`CBaseMACalculator`) resolved the memory footprint problem. However, housing all concrete strategy classes inside a single `MA_CoreCalculators.mqh` still suffered from high coupling: developing a new, unverified algorithm forced developers to constantly re-compile and risk regressions across already verified classes.

### 2.3. The Solution: Component-Based Micro-Kernel Architecture (v3.60)

The architecture was refactored into a **Decoupled Component Architecture (Micro-Kernel with Isolated Plugins)**:

```text
                             [ External Client Indicators ]
                       (MovingAverage_Pro, MACD_Pro, Bollinger_Pro)
                                            │
                                            ▼
                    ┌───────────────────────────────────────────────┐
                    │           MovingAverage_Engine.mqh            │
                    │        (Micro-Kernel Facade & Router)         │
                    └───────────────────────┬───────────────────────┘
                                            │ Includes & Instantiates
                                            ▼
                           MQL5\Include\MyIncludes\MACalculators\
 ┌──────────────────────────────────────────┴──────────────────────────────────────────┐
 │                                                                                     │
 │  ┌───────────────────────┐                                                          │
 │  │  Base_Calculator.mqh  │ <--- Abstract Interface (CBaseMACalculator)              │
 │  └───────────┬───────────┘                                                          │
 │              │ Inherits                                                             │
 │              ▼                                                                      │
 │  ┌───────────────────────┐  ┌───────────────────────┐  ┌───────────────────────┐    │
 │  │  SMA_Calculator.mqh   │  │  SMMA_Calculator.mqh  │  │  VWMA_Calculator.mqh  │    │
 │  └───────────────────────┘  └───────────────────────┘  └───────────────────────┘    │
 │  ┌───────────────────────┐  ┌───────────────────────┐  ┌───────────────────────┐    │
 │  │  EMA_Calculator.mqh   │  │  LWMA_Calculator.mqh  │  │  TMA_Calculator.mqh   │    │
 │  └───────────┬───────────┘  └───────────┬───────────┘  └───────────────────────┘    │
 │              │ Composites               │ Composites                                │
 │              ├──────────────┐           │                                           │
 │              ▼              ▼           ▼                                           │
 │      ┌───────────────┐ ┌─────────┐ ┌─────────┐                                      │
 │      │DEMA_Calculator│ │  TEMA   │ │   HMA   │                                      │
 │      └───────────────┘ └─────────┘ └─────────┘                                      │
 └─────────────────────────────────────────────────────────────────────────────────────┘
```

### The 5 Architectural Pillars

1. **Absolute Blast Radius Elimination:** The 9 verified production algorithms are permanently sealed in their respective `.mqh` files. When you create, test, or fine-tune an experimental algorithm (e.g., `McGinley_Calculator.mqh`), the existing production code is untouched and 100% immune to regressions.
2. **Single Responsibility Principle (SRP) per File:** Exactly one mathematical smoothing model lives in exactly one file.
3. **Clean Composition Over Code Duplication:** Multi-stage algorithms never duplicate code. `DEMA` and `TEMA` composite `CEMACalculator` directly from `EMA_Calculator.mqh`. `HMA` composites `CLWMACalculator` from `LWMA_Calculator.mqh`.
4. **Pay-Only-For-What-You-Use Memory Footprint:** When `SMA` is instantiated, only the basic SMA class is loaded into RAM with zero intermediate dynamic buffers. When `DEMA` is chosen, only its two required stage buffers are allocated.
5. **The Immutable Facade Contract:** All external wrappers (`MovingAverage_Pro.mq5`) and other indicators in the suite interface **only** with `MovingAverage_Engine.mqh`. They are completely decoupled from internal file splits.

---

## 3. Directory Topology & Dependency Layout

The physical directory hierarchy inside the MQL5 terminal:

```text
MQL5\Include\MyIncludes\
│
├── HeikinAshi_Tools.mqh          <-- High-performance synthetic candle DSP
├── DataSync_Tools.mqh            <-- Multi-timeframe asynchronous synchronization
├── MovingAverage_Engine.mqh      <-- Unified Facade & Memory Router
│
└── MACalculators\                <-- Dedicated Modular Engine Directory
    ├── Base_Calculator.mqh       <-- Pure abstract base class interface
    ├── SMA_Calculator.mqh        <-- Simple Moving Average
    ├── EMA_Calculator.mqh        <-- Exponential Moving Average
    ├── SMMA_Calculator.mqh       <-- Smoothed Moving Average (Wilder)
    ├── LWMA_Calculator.mqh       <-- Linear Weighted Moving Average
    ├── TMA_Calculator.mqh        <-- Triangular Moving Average
    ├── DEMA_Calculator.mqh       <-- Double Exponential Moving Average (Composites EMA)
    ├── TEMA_Calculator.mqh       <-- Triple Exponential Moving Average (Composites EMA)
    ├── VWMA_Calculator.mqh       <-- Volume-Weighted Moving Average
    └── HMA_Calculator.mqh        <-- Hull Moving Average (Composites LWMA)
```

---

## 4. The Core Interface Contract (`CBaseMACalculator`)

Every moving average module in `MACalculators\` must inherit from and implement the contract declared in `Base_Calculator.mqh`:

```mql5
class CBaseMACalculator
  {
protected:
   int               m_period;
   double            m_inv_period;

public:
                     CBaseMACalculator(void) : m_period(1), m_inv_period(1.0) {}
   virtual          ~CBaseMACalculator(void) {}

   virtual bool      Init(const int period);
   virtual void      Calculate(const int rates_total,
                               const int start_index,
                               const double &price[],
                               const double &volume[],
                               double &output[],
                               const int data_offset = 0) = 0;

   virtual int       GetWarmupBars(void) const { return m_period - 1; }
  };
```

### Invariants Required by the Contract

- **Chronological Array Ordering:** All input arrays (`price`, `volume`) and output arrays (`output`) are strictly chronological (`ArraySetAsSeries = false`), where index `0` is the oldest historical bar.

- **Deterministic Seeding:** Recursive algorithms must seed their base registers on bars `0 ... warmup-1` strictly when `start_index == 0`.
- **Zero Dynamic Heap Allocations on Live Ticks:** No `new`, `delete`, or unreserved `ArrayResize` operations are permitted inside `Calculate()`. Any internal intermediate arrays must use a minimum capacity reservation of `2048` elements.
- **Thread Safety:** Member functions must never contain `static` array caches. All intermediate buffers must be private class member variables.

---

## 5. Mathematical Foundations of the 9 Validated Models

### 5.1. Simple Moving Average (`SMA_Calculator.mqh`)

Arithmetic mean over a sliding lookback window $P$:
$$\text{SMA}_t = \left(\sum_{j=0}^{P-1} P_{t-j}\right) \times \frac{1}{P}$$
*ALU Optimization:* The division is hoisted out of loops and replaced with precomputed `m_inv_period` multiplication.

---

### 5.2. Exponential Moving Average (`EMA_Calculator.mqh`)

First-order recursive Infinite Impulse Response (IIR) filter:
$$\alpha = \frac{2}{P + 1}, \quad\quad \beta = 1.0 - \alpha$$
$$\text{EMA}_t = P_t \cdot \alpha + \text{EMA}_{t-1} \cdot \beta$$
*Seeding:* The initial value at index $P-1$ is initialized with an exact SMA over the first $P$ bars. Recursive memory is preserved on live market ticks without re-zeroing.

---

### 5.3. Smoothed Moving Average (`SMMA_Calculator.mqh`)

Wilder's recursive smoothing filter (equivalent to an EMA with $\alpha = 1/P$):
$$\text{SMMA}_t = \left(\text{SMMA}_{t-1} \cdot (P - 1) + P_t\right) \times \frac{1}{P}$$

---

### 5.4. Linear Weighted Moving Average (`LWMA_Calculator.mqh`)

Weights prices linearly proportional to their temporal recency ($W_j = P - j$).
The sum of weights is derived analytically via Gauss's summation formula, eliminating the inner-loop weight accumulator:
$$\sum_{j=0}^{P-1} (P - j) = \frac{P(P + 1)}{2}$$
$$\text{LWMA}_t = \left(\sum_{j=0}^{P-1} P_{t-j} \cdot (P - j)\right) \times \frac{1}{\frac{P(P + 1)}{2}}$$

---

### 5.5. Triangular Moving Average (`TMA_Calculator.mqh`)

Double-smoothed simple moving average that forms a triangular-shaped convolution kernel:
$$P_1 = \left\lceil \frac{P + 1}{2} \right\rceil, \quad\quad P_2 = P - P_1 + 1$$
$$\text{Stage 1: } S_t = \text{SMA}(P, P_1), \quad\quad \text{TMA}_t = \text{SMA}(S, P_2)$$
*Pipelined Lookback:* Stage 1 updates across an extended historical window ($P_2 + 1$ bars deeper than the current calculation index) to prevent Stage 2 from reading uncalculated intermediate bars on live ticks.

---

### 5.6. Double Exponential Moving Average (`DEMA_Calculator.mqh`)

Eliminates first-order exponential phase lag:
$$\text{EMA1}_t = \text{EMA}(P, P), \quad\quad \text{EMA2}_t = \text{EMA}(\text{EMA1}, P)$$
$$\text{DEMA}_t = 2 \cdot \text{EMA1}_t - \text{EMA2}_t$$
*Composites `CEMACalculator` for both Stage 1 and Stage 2.*

---

### 5.7. Triple Exponential Moving Average (`TEMA_Calculator.mqh`)

Eliminates first- and second-order exponential phase lag for near-zero latency tracking:
$$\text{EMA1}_t = \text{EMA}(P, P), \quad \text{EMA2}_t = \text{EMA}(\text{EMA1}, P), \quad \text{EMA3}_t = \text{EMA}(\text{EMA2}, P)$$
$$\text{TEMA}_t = 3 \cdot \text{EMA1}_t - 3 \cdot \text{EMA2}_t + \text{EMA3}_t$$
*Composites `CEMACalculator` across all three cascading stages.*

---

### 5.8. Volume-Weighted Moving Average (`VWMA_Calculator.mqh`)

Weights price bars directly proportional to transacted trade volume ($V_t$):
$$\text{VWMA}_t = \frac{\sum_{j=0}^{P-1} P_{t-j} \cdot V_{t-j}}{\sum_{j=0}^{P-1} V_{t-j}}$$
*Zero-Volume Fallback:* If trading volume is 0 or unavailable, volume defaults to $1.0$, collapsing safely into an SMA.

---

### 5.9. Hull Moving Average (`HMA_Calculator.mqh`)

Alan Hull's low-lag, highly responsive trend filter that combines two fast/slow WMA passes with a final square-root smoothing pass:
$$\text{half} = \max\left(1, \left\lfloor \frac{P}{2} \right\rfloor\right), \quad\quad \text{smooth} = \max\left(1, \text{round}\left(\sqrt{P}\right)\right)$$
$$\text{raw}_t = 2 \cdot \text{LWMA}(P, \text{half})_t - \text{LWMA}(P, P)_t$$
$$\text{HMA}_t = \text{LWMA}(\text{raw}, \text{smooth})_t$$
*Warmup Formula:* Exactly $P + \text{smooth} - 1$ bars. Composites three `CLWMACalculator` instances with an internal `m_raw_buffer[]`.

---

## 6. DSP Filtering & Performance Matrix

| Algorithm | Phase Latency (Lag) | Spectral Smoothing | Noise Sensitivity | Optimal Market Application |
| :--- | :---: | :---: | :---: | :--- |
| **SMA** | High | Medium | Very Low | Macro benchmark filters (50/200 Day benchmarks). |
| **EMA** | Medium | High | Medium | Classical trend-following, dynamic envelopes, MACD line. |
| **SMMA** | High | Very High | Very Low | Wilder indicators (RSI, ADX, ATR, Volatility Bands). |
| **LWMA** | Low | Medium | High | Short-term momentum tracking, fast directional scalping. |
| **TMA** | Very High | Ultra-High | Zero | Dominant cycle wave extraction; suppresses high frequencies. |
| **DEMA** | Very Low | Medium | High | Swing breakouts; reduces ~50% of standard EMA lag. |
| **TEMA** | Near-Zero | Low | Very High | High-frequency microstructure reaction; instant turns. |
| **VWMA** | Dynamic | High | Volume-Adaptive | Institutional liquidity analysis; volume-confirmed trends. |
| **HMA** | Near-Zero | Very High | Low | Low-lag trend trading without the noise/whipsaw of TEMA. |

---

## 7. Developer Protocol: Adding New Algorithms in 3 Simple Steps

When you develop or test a new algorithm (e.g., **McGinley Dynamic**, **ZLEMA**, **EHMA**, **MedianMA**, **SWMA**, **KAMA**, or **ALMA**), follow this exact isolated workflow:

### Step 1: Create the Isolated Engine File

Create a new file in `MQL5\Include\MyIncludes\MACalculators\[Name]_Calculator.mqh`:

```mql5
//+------------------------------------------------------------------+
//|                                         McGinley_Calculator.mqh  |
//+------------------------------------------------------------------+
#ifndef MCGINLEY_CALCULATOR_MQH
#define MCGINLEY_CALCULATOR_MQH

#include <MyIncludes\MACalculators\Base_Calculator.mqh>

class CMCGinleyCalculator : public CBaseMACalculator
  {
private:
   double m_k_period;

public:
   virtual bool Init(const int period) override
     {
      if(!CBaseMACalculator::Init(period)) return false;
      m_k_period = 0.6 * (double)m_period;
      return true;
     }

   virtual void Calculate(const int rates_total, const int start_index,
                          const double &price[], const double &volume[],
                          double &output[], const int data_offset = 0) override
     {
      // Isolated mathematical implementation...
     }

   virtual int GetWarmupBars(void) const override { return m_period - 1; }
  };

#endif // MCGINLEY_CALCULATOR_MQH
```

### Step 2: Register in `MovingAverage_Engine.mqh`

1. Include the new file at the top of `MovingAverage_Engine.mqh`:

   ```mql5
   #include <MyIncludes\MACalculators\McGinley_Calculator.mqh>
   ```

2. Add the identifier to `ENUM_MA_TYPE`:

   ```mql5
   enum ENUM_MA_TYPE
     {
      // ... existing 9 algorithms ...
      HMA,
      MCGINLEY // <-- New Algorithm Registered
     };
   ```

### Step 3: Wire into the Factory Method

Add a single switch case to `CMovingAverageCalculator::CreateAlgorithm()`:

```mql5
case MCGINLEY: m_algo = new CMCGinleyCalculator(); break;
```

**Result:** The new algorithm is instantly operational across the entire ecosystem. It automatically inherits MTF fast-path routing, Heikin Ashi pricing, dynamic visual clipping, and EA integration—while the 9 existing production algorithms remain completely untouched and verified.

---

## 8. Multi-Timeframe (MTF) Two-Pointer Fast-Path Protocol

When `InpTimeframe > Period()`, the indicator activates the synchronized institutional Fast-Path MTF engine:

```text
  HTF Domain (e.g., H1)
  [ HTF Bar 0 ]────────────────────────>[ HTF Bar 1 ]────────────────────────>[ HTF Forming ]
        │                                     │                                     │
        ▼ (Chronological 2-Pointer Projection)▼                                     ▼
  LTF Domain (e.g., M5)
  [m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5][m5]
  └───────────────────┘ └───────────────────┘ └───────────────────┘ └───────────────────────┘
     Flat Step 0           Flat Step 1           Flat Step 2           Forming Block (Live)
```

1. **Atomic Bulk Rates Synchronization:** On HTF bar closure or startup, a single atomic `CopyRates()` call queries all necessary HTF candles into chronological caches (`h_open`, `h_high`, `h_low`, `h_close`, `h_vol`).
2. **Two-Pointer Chronological Sweep ($O(N)$ Projection):** Maps computed HTF values onto LTF chart bars in a single forward pass without calling the slow `iBarShift()` API:

   ```mql5
   int htf_ptr = 0;
   for(int i = 0; i < rates_total; i++)
     {
      while(htf_ptr + 1 < g_htf_count && h_time[htf_ptr + 1] <= time[i])
         htf_ptr++;
      BufferMA[i] = h_res_ma[htf_ptr];
     }
   ```

3. **Live-Tick RAM Mocking & Binary Snapping:** When ticks occur inside a forming HTF candle, only the forming candle in RAM (`live_idx = g_htf_count - 1`) is updated. An $O(\log N)$ binary search (`ArrayBsearch`) locates the first LTF bar belonging to the forming HTF block and refreshes the values across the forming block in nanoseconds.

---

## 9. Parameters Reference

### Timeframe Settings

- **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Target timeframe. When set to `PERIOD_CURRENT`, it operates in native zero-lag mode. When set to a higher timeframe (`PERIOD_M15` through `PERIOD_MN1`), it projects a flat-stepped MTF baseline. Must be $\ge$ chart timeframe.

### Moving Average Core Settings

- **`InpPeriod`** (*default: `20`*): The lookback smoothing period ($P$). Must be an integer $\ge 1$.

- **`InpMAType`** (*default: `SMA`*): Mathematical smoothing algorithm selection:
  - `SMA`: Simple Moving Average
  - `EMA`: Exponential Moving Average
  - `SMMA`: Smoothed Moving Average (Wilder's RMA)
  - `LWMA`: Linear Weighted Moving Average
  - `TMA`: Triangular Moving Average
  - `DEMA`: Double Exponential Moving Average
  - `TEMA`: Triple Exponential Moving Average
  - `VWMA`: Volume-Weighted Moving Average
  - `HMA`: Hull Moving Average
- **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Input price series. Supports all 7 Standard applied prices and all 7 filtered Heikin Ashi prices (`PRICE_HA_CLOSE` through `PRICE_HA_WEIGHTED`).

### Visual Settings

- **`InpColorMA`** (*default: `clrDodgerBlue`*): Moving average line color.

- **`InpStyleMA`** (*default: `STYLE_SOLID`*): Line style (Solid, Dash, Dot).
- **`InpWidthMA`** (*default: `2`*): Line thickness in pixels.

---

## 10. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   MOVING AVERAGE TRADING PLAYBOOKS                     │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Dynamic Baseline Retest: Pullbacks to rising EMA/VWMA/HMA offer     │
│                             high-probability trend continuation.       │
│ 2. Institutional Cross:     50 EMA crossing above 200 SMA confirms a   │
│                             macro Golden Cross regime shift.           │
│ 3. MTF Macro Step Filter:   Only execute M5 long setups when price is  │
│                             trading above the H1 50 EMA flat step.     │
└────────────────────────────────────────────────────────────────────────┘
```

### 10.1. Dynamic Baseline Pullbacks

- **Bullish Setup:** Market is in an established markup phase above a rising **`20 EMA`**, **`20 VWMA`**, or **`20 HMA`**. Price retraces to test the dynamic moving average and prints a rejection candle with a lower wick $\rightarrow$ Long continuation entry.

- **Bearish Setup:** Market is in a markdown phase below a falling moving average. Price pulls back upward to retest the line from below $\rightarrow$ Short continuation entry.

### 10.2. Golden Cross & Death Cross Confirmation

- **Golden Cross (Macro Expansion):** A fast moving average (e.g., `50 EMA`) crosses **above** a slower baseline (e.g., `200 SMA`) with rising trading volume $\rightarrow$ Institutional confirmation of a long-term bull market.

- **Death Cross (Macro Contraction):** The fast moving average crosses **below** the slower baseline $\rightarrow$ Institutional confirmation of a bear market.

### 10.3. Multi-Timeframe Macro Step Alignment

- Attach an **H1-calculated 50 EMA** onto an **M5 execution chart**.

- **Quantitative Execution Rule:**
  $$\text{If } \text{Bid} > \text{BufferMA}_{\text{H1 Step}} \implies \text{Long Trades Permitted Only}$$
  $$\text{If } \text{Bid} < \text{BufferMA}_{\text{H1 Step}} \implies \text{Short Trades Permitted Only}$$
- Eliminates counter-trend scalping against higher-timeframe institutional order flow.

---

## 11. Indicator Buffer Map & Developer API

### Output Buffers

| Buffer Index | Identifier | Type | Description |
| :---: | :---: | :---: | :--- |
| **0** | `BufferMA` | `INDICATOR_DATA` | Universal Moving Average plot line |

*Buffer indexing strictly enforces chronological ordering (`ArraySetAsSeries = false`), where index `0` represents the oldest bar in history and index `rates_total - 1` represents the currently forming bar.*

### Expert Advisor / Scanner Integration (`iCustom`)

To call `MovingAverage_Pro` from an Expert Advisor or multi-symbol dashboard:

```mql5
//--- Create indicator handle
int handle = iCustom(_Symbol, _Period, "MovingAverage_Pro",
                     PERIOD_CURRENT,     // InpTimeframe
                     20,                 // InpPeriod
                     HMA,                // InpMAType (ENUM_MA_TYPE)
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
