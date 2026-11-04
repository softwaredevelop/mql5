# Initial Balance (IB) Breakout & Statistical Open Forecast Pro (v2.40)

## Institutional Market Profile & Auction Market Theory Open Analysis Suite

**Enterprise Ultra Edition — Multi-Session Engine for MetaTrader 5*

---

## 1. Executive Summary & Market Profile Overview

**Initial Balance Breakout Pro** is an institutional-grade open-range analysis suite designed for MetaTrader 5. Operating on Peter Steidlmayer's **Auction Market Theory (AMT)** and classical **Market Profile** principles, the suite models price discovery during the critical opening phase of trading sessions.

During the opening minutes of a market session (typically the first 30 to 60 minutes), institutional order flow enters the market to discover price, balance overnight inventory, and establish the session's initial liquidity boundaries:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   INITIAL BALANCE (IB) ANATOMY                         │
├────────────────────────────────────────────────────────────────────────┤
│  Top Extension N:  Top + N · Step · (Top - Bottom)                     │
│  Top Extension 1:  Top + 1 · Step · (Top - Bottom)                     │
│  ────────────────────────────────────────────────────────────────────  │
│  IB High (Top):    Highest print during the initial balance window     │
│  Fibonacci Levels: 0.236, 0.382, 0.500, 0.618, 0.786                   │
│  IB Midline:       Exact 50% Equilibrium / Fair Value Pivot            │
│  IB Low (Bottom):  Lowest print during the initial balance window      │
│  ────────────────────────────────────────────────────────────────────  │
│  Bot Extension 1:  Bottom - 1 · Step · (Top - Bottom)                  │
│  Bot Extension N:  Bottom - N · Step · (Top - Bottom)                  │
└────────────────────────────────────────────────────────────────────────┘
```

### Key Architectural Capabilities

- **Engine-Wrapper Decoupled Architecture:** High-performance, headless mathematical calculation engine (`InitialBalance_Engine.mqh`) coupled with a DirectX-optimized visual wrapper (`InitialBalance_Breakout_Pro.mq5`).
- **Multi-Instance Namespace Isolation:** Unique instance tagging (`InpSessionName`) isolates chart objects, enabling simultaneous, independent tracking of **London, New York, and Asian sessions** on the same chart window with zero object collisions.
- **Consolidated Multi-Tier Range Extensions:** Single and multi-tier extension grids unified into a single parameter structure with independent directional visibility (Top vs. Bottom).
- **Extended Fibonacci Equilibrium Matrix:** Full session-length projection of internal Fibonacci retracements to track post-breakout pullback reactions.
- **Dual-Mode Statistical Forecast Engine:** Projects expected session extremes using trailing empirical deviations (Global Previous Open vs. Day-of-Week Specific).
- **Zero-Lag EA Breakout Integration:** Real-time breakout signals output directly into native indicator buffers (`DRAW_ARROW`), ready for instant execution via Expert Advisors (`iCustom`).

---

## 2. Mathematical Foundations & Structural Levels

```text
        SESSION START                       IB END                      SESSION END
              │                               │                              │
              ▼                               ▼                              ▼
  [─── Formation Window ───] [────────────── Breakout Monitoring Window ──────────────]
      Price tests High/Low       Breakout signals armed; Extensions & Forecasts active
```

### 2.1. Initial Balance Core Box

For a session starting at time $T_{start}$ and concluding formation at $T_{ib}$:
$$\text{IB Top} = \max_{t \in [T_{start}, T_{ib}]} (\text{High}_t)$$
$$\text{IB Bottom} = \min_{t \in [T_{start}, T_{ib}]} (\text{Low}_t)$$
$$\text{IB Range } (R) = \text{IB Top} - \text{IB Bottom}$$

### 2.2. Initial Balance Midline (50% Fair Value Pivot)

The arithmetic mean of the initial balance boundaries represents the primary intraday equilibrium anchor:
$$\text{IB Midline} = \frac{\text{IB Top} + \text{IB Bottom}}{2} = \text{IB Bottom} + 0.5 \times R$$
*Market Context:* In Auction Market Theory, prices holding above the Midline post-breakout confirm buyer dominance. Retests of the Midline that fail to hold signal an impending mean-reversion move to the opposite side of the balance.

### 2.3. Consolidated Multi-Tier Range Extensions

Extensions represent volatility expansion targets beyond the established opening range. Configured by step percentage $S$ (`InpExtPercent`) and count $N$ (`InpExtCount`):
$$\text{TopExt}_k = \text{IB Top} + \left(k \times \frac{S}{100} \times R\right), \quad \forall k \in [1, N]$$
$$\text{BotExt}_k = \text{IB Bottom} - \left(k \times \frac{S}{100} \times R\right), \quad \forall k \in [1, N]$$
*Independent Directional Control:* Top and Bottom extension grids can be toggled independently (`InpShowTopExt` and `InpShowBottomExt`), allowing clean, one-sided projection during established directional market regimes.

### 2.4. Fibonacci Retracement Levels

Within the core opening range $R$, 5 harmonic equilibrium levels are projected across the entire breakout window:
$$\text{FibLevel}_f = \begin{cases}
\text{IB Top} - \text{Ratio}_f \times R & \text{if } \text{InpFiboReverse} = \text{false} \\
\text{IB Bottom} + \text{Ratio}_f \times R & \text{if } \text{InpFiboReverse} = \text{true}
\end{cases}$$
Where $\text{Ratio} \in \{0.236, 0.382, 0.500, 0.618, 0.786\}$.

### 2.5. Breakout Detection State Machine
Breakouts are monitored strictly after the IB formation window has elapsed ($t \ge T_{ib}$):
* **Bullish Breakout:** Bar close breaches above the IB High:
  $$\text{Close}_{t-1} \le \text{IB Top} \quad \land \quad \text{Close}_t > \text{IB Top}$$
* **Bearish Breakout:** Bar close breaches below the IB Low:
  $$\text{Close}_{t-1} \ge \text{IB Bottom} \quad \land \quad \text{Close}_t < \text{IB Bottom}$$
*Once triggered, an internal software latch disarms repeated signals to prevent indicator buffer spamming on successive trending bars.*

---

## 3. Statistical Open Forecast Engine

The indicator includes a statistical predictive model that projects expected session expansion boundaries before the breakout occurs.

```text
                            HISTORICAL MEMORY (N Sessions)
               ┌──────────────────────────────────────────────────────┐
               │ Session k-1:  ΔTop = High - Open,  ΔBot = Low - Open  │
               │ Session k-2:  ΔTop = High - Open,  ΔBot = Low - Open  │
               │ Session k-N:  ΔTop = High - Open,  ΔBot = Low - Open  │
               └──────────────────────────┬───────────────────────────┘
                                          │ Rolling Expectancy
                                          ▼
                      Current Open + Multiplier · Mean(Δ)
```

### 3.1. Mode 1: Against Previous Open (`FORECAST_PREV_OPEN`)
Measures the historical excursion of the IB relative to the **preceding session's opening price**:
$$\Delta \text{Top}_k = \text{Top}_k - \text{Open}_{k-1}$$
$$\Delta \text{Bot}_k = \text{Bottom}_k - \text{Open}_{k-1}$$
$$\text{Forecast Top} = \text{Open}_{today} + M \times \frac{1}{N} \sum_{i=1}^N \Delta \text{Top}_i$$
$$\text{Forecast Bot} = \text{Open}_{today} + M \times \frac{1}{N} \sum_{i=1}^N \Delta \text{Bot}_i$$

### 3.2. Mode 2: Filter by Current Day of Week (`FORECAST_DAY_OF_WEEK`)
Filters excursions specifically by the day of the week (e.g., comparing Mondays exclusively against previous Mondays) to account for weekly volume seasonality:
$$\Delta \text{Top}_{dow, k} = \text{Top}_k - \text{Open}_k$$
$$\Delta \text{Bot}_{dow, k} = \text{Bottom}_k - \text{Open}_k$$
$$\text{Forecast Top} = \text{Open}_{today} + M \times \frac{1}{N_{dow}} \sum_{i=1}^{N_{dow}} \Delta \text{Top}_{dow, i}$$
$$\text{Forecast Bot} = \text{Open}_{today} + M \times \frac{1}{N_{dow}} \sum_{i=1}^{N_{dow}} \Delta \text{Bot}_{dow, i}$$

---

## 4. Multi-Instance Architecture & Session Isolation

To analyze multiple market opens on the same chart (e.g., **London Open** at 09:00 broker time and **New York Open** at 15:30 broker time), the indicator employs the **Deterministic Instance Namespace Pattern**:

```mql5
g_prefix = StringFormat("IB_%I64d_%s_", ChartID(), InpSessionName);
```

Because every graphical object created begins with `g_prefix`, instances never overwrite or delete each other's visual elements.

### Multi-Session Configuration Guide (Simultaneous Chart Setup)

Attach the indicator twice to the same chart with the following settings:

| Parameter | Instance 1: London Session | Instance 2: New York Session |
| :--- | :--- | :--- |
| **`InpSessionName`** | `"London"` | `"NewYork"` |
| **`InpAutoSession`** | `false` | `false` |
| **`InpIBDurationMinutes`**| `60` | `60` |
| **`InpManualIBStart`** | `"09:00"` (Broker Time) | `"15:30"` (Broker Time) |
| **`InpManualIBEnd`** | `"10:00"` | `"16:30"` |
| **`InpManualSessionEnd`** | `"17:30"` (EU Close) | `"22:00"` (US Close) |
| **`InpDisplaySessions`** | `1` | `1` |
| **`InpIBColorTop / Bot`** | `clrDodgerBlue` / `clrOrange` | `clrForestGreen` / `clrCrimson` |

---

## 5. Parameters Reference

### === Session & Multi-Instance Identity ===
* **`InpSessionName`** (*default: `"London"`*): Unique text identifier for the session instance. Used to prefix chart objects and prevent collisions.
* **`InpAutoSession`** (*default: `false`*): When `true`, automatically begins the IB on the day's first bar. When `false`, uses manual time strings.
* **`InpIBDurationMinutes`** (*default: `60`*): Initial Balance formation window length in minutes.
* **`InpManualIBStart`** (*default: `"09:00"`*): Session start time (`HH:MM`).
* **`InpManualIBEnd`** (*default: `"10:00"`*): Initial Balance conclusion time (`HH:MM`).
* **`InpManualSessionEnd`** (*default: `"17:30"`*): Session and breakout monitoring conclusion time (`HH:MM`).

### === Initial Balance Base Styling ===
* **`InpIBWidth`** (*default: `2`*): Line thickness for IB High and Low baseline boundaries.
* **`InpIBStyle`** (*default: `STYLE_SOLID`*): Line style for IB High and Low boundaries.
* **`InpIBColorTop`** (*default: `clrForestGreen`*): Color of the IB High level.
* **`InpIBColorBottom`** (*default: `clrCrimson`*): Color of the IB Low level.
* **`InpShowIBBox`** (*default: `true`*): Toggles the background range rectangle.
* **`InpIBBoxColor`** (*default: `clrLightSlateGray`*): Color of the formation background box.
* **`InpShowIBMidline`** (*default: `true`*): Toggles the 50% Fair Value Midline.
* **`InpIBMidWidth`** (*default: `1`*): Line thickness for the Midline.
* **`InpIBMidStyle`** (*default: `STYLE_DASH`*): Line style for the Midline.
* **`InpIBMidColor`** (*default: `clrGold`*): Color of the Midline.

### === Range Extensions Styling ===
* **`InpShowTopExt`** (*default: `true`*): Toggles upper extension levels.
* **`InpShowBottomExt`** (*default: `true`*): Toggles lower extension levels.
* **`InpExtCount`** (*default: `1`*): Number of extension tiers to project ($1 = \text{Single}, 2+ = \text{Multi-Tier Grid}$).
* **`InpExtPercent`** (*default: `50.0`*): Expansion step percentage relative to the IB Range (e.g., $50 = +0.5\times R$ per level).
* **`InpExtWidth`** (*default: `1`*): Line thickness for all extension lines.
* **`InpExtStyle`** (*default: `STYLE_DASH`*): Line style for all extension lines.
* **`InpExtColorTop`** (*default: `clrForestGreen`*): Color for upper extension lines.
* **`InpExtColorBottom`** (*default: `clrCrimson`*): Color for lower extension lines.

### === Fibonacci Equilibrium Levels Styling ===
* **`InpShowFibos`** (*default: `true`*): Toggles the internal Fibonacci retracement grid.
* **`InpFiboReverse`** (*default: `false`*): Reverses retracement orientation ($0\%$ at Low vs. $0\%$ at High).
* **`InpFiboWidth`** (*default: `1`*): Line thickness for Fibonacci levels.
* **`InpFiboStyle`** (*default: `STYLE_DOT`*): Line style for Fibonacci levels.
* **`InpFiboColor`** (*default: `clrSilver`*): Color for Fibonacci levels.

### === Statistical Forecast Styling ===
* **`InpShowForecast`** (*default: `true`*): Toggles statistical range forecast levels.
* **`InpForecastMode`** (*default: `FORECAST_PREV_OPEN`*): Statistical model (`FORECAST_PREV_OPEN` or `FORECAST_DAY_OF_WEEK`).
* **`InpForecastMemory`** (*default: `10`*): Historical sample size (number of prior sessions).
* **`InpForecastMult`** (*default: `1.0`*): Multiplier applied to the average historical deviation.
* **`InpForecastWidth`** (*default: `1`*): Line thickness for forecast levels.
* **`InpForecastStyle`** (*default: `STYLE_DASHDOT`*): Line style for forecast levels.
* **`InpForecastTopColor`** (*default: `clrMediumSeaGreen`*): Color for the upper forecast target.
* **`InpForecastBotColor`** (*default: `clrIndianRed`*): Color for the lower forecast target.

### === Signals & Chart Hygiene ===
* **`InpShowBreakoutArrows`** (*default: `true`*): Toggles visual breakout arrow signals on the chart.
* **`InpDisplaySessions`** (*default: `1`*): Number of historical sessions to render simultaneously.

---

## 6. Quantitative Trading Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                   INITIAL BALANCE TRADING PLAYBOOKS                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Trend Day Expansion:  Bar closes outside IB -> Enter continuation;  │
│                          scale out at Extension 1, 2, and 3.           │
│ 2. Failed Breakout Fade: Price breaches IB, fails, and closes back     │
│                          across Midline -> Reversion to opposite IB.   │
│ 3. Mean Reversion Band:  Price stays bounded -> Trade Fib 0.236/0.786  │
│                          reversals toward the 50% Midline.             │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Trend Day Expansion
* **Market Context:** Aggressive institutional initiative order flow enters post-open.
* **Entry Trigger:** An M5 bar closes outside the IB range (`Close > IB Top` or `Close < IB Bottom`), printing a Breakout Arrow.
* **Target Management:** Scale out in tiers using the Multi-Tier Extension grid:
  - Take Profit 1: **Extension 1** ($+0.5\times R$)
  - Take Profit 2: **Extension 2** ($+1.0\times R$)
  - Take Profit 3: **Extension 3** ($+1.5\times R$) or Statistical Forecast target.
* **Protective Stop:** Placed on the opposite side of the **IB Midline**.

### 6.2. Playbook 2: Failed Breakout (The Auction Reversal)
* **Market Context:** Liquidity hunt outside the opening range that fails to find acceptance.
* **Setup:** Price spikes beyond the IB Top/Bottom, but fails to sustain. Price aggressively reverses and prints a bar closing back across the **IB Midline**.
* **Trade:** Enter market in the direction of the reversal toward the opposite side of the balance (e.g., Short target = **IB Bottom**).

---

## 7. Indicator Buffer Map & EA Integration

The indicator maps breakout events directly to native output buffers, enabling sub-millisecond execution via automated trading systems.

### Output Buffer Indexing

| Buffer Index | Identifier | Type | Value When Active | Value When Inactive | Description |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **0** | `BufferBreakoutUp` | `INDICATOR_DATA` | `Low - 5*Point` | `EMPTY_VALUE` | Bullish IB Breakout (Closed above IB Top) |
| **1** | `BufferBreakoutDown` | `INDICATOR_DATA` | `High + 5*Point` | `EMPTY_VALUE` | Bearish IB Breakout (Closed below IB Low) |

*Buffers strictly maintain non-series chronological ordering (`ArraySetAsSeries = false`), where the latest bar resides at index `rates_total - 1`.*

### Expert Advisor / Scanner Integration (`iCustom`)

Example MQL5 snippet to read breakout signals from an Expert Advisor:

```mql5
//--- Create handle for London Session Initial Balance
int h_ib = iCustom(_Symbol, _Period, "InitialBalance_Breakout_Pro",
                   "London",            // InpSessionName
                   false,               // InpAutoSession
                   60,                  // InpIBDurationMinutes
                   "09:00",             // InpManualIBStart
                   "10:00",             // InpManualIBEnd
                   "17:30"              // InpManualSessionEnd
                   // ... visual parameters fall back to defaults
                  );

if(h_ib == INVALID_HANDLE)
  {
   Print("Critical Error: Failed to create InitialBalance_Breakout_Pro handle.");
   return;
  }

//--- Read the closed bar (bar index 1)
double bull_signal[], bear_signal[];
ArraySetAsSeries(bull_signal, true);
ArraySetAsSeries(bear_signal, true);

if(CopyBuffer(h_ib, 0, 1, 1, bull_signal) == 1 &&
   CopyBuffer(h_ib, 1, 1, 1, bear_signal) == 1)
  {
   if(bull_signal[0] != EMPTY_VALUE && bull_signal[0] > 0.0)
     {
      // Execute Buy Order (Bullish Initial Balance Breakout)
     }
   else if(bear_signal[0] != EMPTY_VALUE && bear_signal[0] > 0.0)
     {
      // Execute Sell Order (Bearish Initial Balance Breakout)
     }
  }
```
