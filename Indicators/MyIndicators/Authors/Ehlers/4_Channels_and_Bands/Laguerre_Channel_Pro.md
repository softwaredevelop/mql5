# Laguerre Channel Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Laguerre Channel Pro Suite** represents a modern, institutional-grade evolution of the classic Keltner Channel. By replacing the traditional Moving Average middle line with John Ehlers' advanced **Laguerre Filter**, these indicators offer superior responsiveness, minimal phase lag, and ultra-smooth volatility boundaries.

The suite consists of two professional-grade indicators designed for different trading and execution styles:

1. **`Laguerre_Channel_Pro`**: Standard version using a low-lag Laguerre Filter with a fixed, user-definable `Gamma` on the current chart timeframe.
2. **`Laguerre_Channel_MTF_Pro`**: Multi-Timeframe version that projects the higher timeframe's low-lag Laguerre Filter baseline and Average True Range (ATR) volatility channels directly onto the lower timeframe chart.

Both indicators utilize **Average True Range (ATR)** bands as multipliers to define dynamic support and resistance levels. This creates a highly adaptive, zero-lag envelope system ideal for identifying macro trends, pullback entries, and mean reversion opportunities.

---

## 2. Mathematical Foundations and Calculation Logic

The Laguerre Channel is constructed by creating a volatility-based channel around a central low-lag Laguerre moving average.

### A. Middle Line (Laguerre Basis - $G_t$)

The central baseline is computed using Ehlers' recursive 4-Pole Laguerre filter with a damping factor $\gamma$ (`InpGamma` $\in [0.0, 1.0]$):

$$L_{0, t} = (1 - \gamma) P_t + \gamma L_{0, t-1}$$

$$L_{1, t} = -\gamma L_{0, t} + L_{0, t-1} + \gamma L_{1, t-1}$$

$$L_{2, t} = -\gamma L_{1, t} + L_{1, t-1} + \gamma L_{2, t-1}$$

$$L_{3, t} = -\gamma L_{2, t} + L_{2, t-1} + \gamma L_{3, t-1}$$

$$\text{Middle Line}_t = \frac{L_{0, t} + 2L_{1, t} + 2L_{2, t} + L_{3, t}}{6}$$

### B. Average True Range (ATR Volatility Bands)

The channel width is determined by the Average True Range (ATR) calculated over a user-defined period $P_{\text{atr}}$ (`InpAtrPeriod`):

$$\text{ATR}_t = \frac{1}{P_{\text{atr}}} \sum_{k=0}^{P_{\text{atr}}-1} \text{TR}_{t-k}$$

### C. Upper and Lower Band Calculations

The dynamic outer boundaries are projected by adding and subtracting a multiple $M$ (`InpMultiplier`) of the ATR from the Middle Line:

$$\text{Upper Band}_t = \text{Middle Line}_t + (M \times \text{ATR}_t)$$

$$\text{Lower Band}_t = \text{Middle Line}_t - (M \times \text{ATR}_t)$$

---

## 3. Advanced MQL5 MTF Implementation Details

`Laguerre_Channel_MTF_Pro` utilizes our state-of-the-art multi-timeframe engine to project macro volatility channels onto micro execution charts with absolute precision.

### A. Forming LTF Block Flat-Force (The Warping Solution)

MTF channel indicators often suffer from visual warping (the live-bar warping bug where only the very last LTF bar gets updated, creating a jagged, diagonal line across the active HTF block). The suite resolves this by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, g_calc_timeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

By forcing a full-block rewrite on every live tick, the active HTF step (Middle, Upper, and Lower bands) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Strict Non-Repainting State Safety on Live Ticks (State Mocking)

To support real-time updating without modifying closed historical states (which would cause severe repainting and backtesting discrepancies), the MTF indicator utilizes a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator).

This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting, double-accumulating, or corrupting any historical states inside the recursive Laguerre and ATR registers.

### C. Asynchronous Timer Guard & Hybrid HA Pricing

* **Background Timer:** High-frequency MTF data requests often suffer from terminal loading gaps. A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as history is ready.

* **Hybrid HA Pricing:** Standard pricing is used by default. An inherited `CLaguerreChannelCalculator_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data, leveraging the same optimized engine.

---

## 4. Parameters

### A. Timeframe Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate Laguerre channels on (Default: `PERIOD_H1`).

### B. Laguerre Settings

* **Gamma (`InpGamma`):** The Laguerre filter damping coefficient, a value between 0.0 and 1.0. This parameter controls the trade-off between smoothing and lag (Default: `0.7`).

* **Price Source (`InpSourcePrice`):** Selects the price series source, supporting Standard and Heikin Ashi prices (Default: `PRICE_CLOSE_STD`).

### C. Channel (ATR) Settings

* **ATR Period (`InpAtrPeriod`):** The lookback period for the Average True Range volatility calculation (Default: `14`).

* **Multiplier (`InpMultiplier`):** The multiplier used to adjust the channel width (Default: `2.0`).
* **ATR Source (`InpAtrSource`):** Select between standard candles (`ATR_SOURCE_STANDARD`) or Heikin Ashi candles (`ATR_SOURCE_HEIKIN_ASHI`) to compute volatility.

---

## 5. Usage and Trading Strategies

### A. Trend Breakouts (Climatic Efficiency)

* **Signal:** A lower-timeframe candle closes completely **outside** the Laguerre Channel (above the Upper Band or below the Lower Band).

* **Confirmation:** The Middle Line (Laguerre Filter) must be sloping in the direction of the breakout.
* **Exit:** When price closes back inside the channel or crosses the Middle Line.

### B. Trend Pullback Entries (The "Basis" Touch)

In a strongly trending market, John Ehlers' low-lag Middle Line acts as an exceptionally reliable dynamic support/resistance level:

1. Identify a strong trend (price is consistently riding the Upper/Lower band).
2. Wait for a pullback where the price touches or slightly pierces the **Middle Line (Basis)**.
3. Enter in the direction of the major trend if the Middle Line holds as support/resistance.

### C. Mean Reversion (Ranging Markets)

When the Middle Line is flat (horizontal), the outer bands act as extreme statistical boundaries:

* **Signal:** Price touches or pierces the Upper/Lower Bands.
* **Action:** Trade counter-trend back towards the Middle Line (Fair Value).

### D. Top-Down Macro Channel Play (MTF Core Strategy)

1. **Macro Volatility Corridor (H1/H4):** Apply `Laguerre_Channel_MTF_Pro` set to H1 or H4 on an M5/M15 execution chart.
2. **The Trend Alignment:** Identify the macro trend direction based on the slope of the **H1 MTF Middle Line**. If the macro Middle Line is sloping upward, only seek buy setups on the lower timeframe.
3. **The Local Entry:** When the local M5 price pulls back and touches the macro **H1 MTF Lower Band** (or macro Middle Line), execute high-probability **BUY** entries. This lets you enter trades at extremely cheap macro prices while maintaining tight stop-losses on the lower timeframe.
