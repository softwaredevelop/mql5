# DMI Stochastic Pro Suite (Standard, Adaptive & MTF)

## 1. Summary (Introduction)

The **DMI Stochastic Pro Suite** is an institutional-grade, high-performance separate window momentum-of-momentum oscillator suite comprising four advanced technical indicators:

* `DMIStochastic_Pro` (Standard %K + Signal %D)
* `DMIStochastic_MTF_Pro` (Multi-Timeframe Standard %K + Signal %D)
* `DMIStochastic_Adaptive_Pro` (Adaptive Lookback %K + Signal %D)
* `DMIStochastic_Adaptive_MTF_Pro` (Multi-Timeframe Adaptive %K + Signal %D)

Developed by Barbara Star, the DMI Stochastic is an innovative oscillator that combines J. Welles Wilder's Directional Movement Index (DMI) and the Stochastic Oscillator.

Instead of analyzing raw prices, this indicator measures the **momentum of the underlying directional pressure** in the market. It does this by creating a dynamic DMI Oscillator from the difference between the Positive (+DI) and Negative (-DI) Directional Indicators, and then feeding this new value series into a standard Stochastic calculation.

The **Adaptive** versions enhance this concept by integrating Perry Kaufman's **Efficiency Ratio (ER)**. Instead of using a fixed lookback, the adaptive engine dynamically adjusts its Stochastic window based on market efficiency—shortening the period during high-efficiency trends (for fast response) and lengthening it during low-efficiency consolidations (for noise filtering).

The suite features Heikin Ashi price smoothing, **Forming LTF Block Flat-Force** step-blocking, and a dynamic volume-routing pipeline to support volume-weighted moving average (VWMA) smoothing.

---

## 2. Mathematical Foundations and Calculation Logic

The calculation is a multi-stage process: first building the DMI components, then creating the DMI Oscillator, optionally calculating the Efficiency Ratio (ER), and finally applying the Stochastic formula.

### A. Step 1: Directional Indicators (+DI, -DI)

Raw Directional Movement (+DM, -DM) and True Range (TR) are calculated for each bar and smoothed using Wilder's method over period $P$ (`InpDMIPeriod`):

$$\text{+DI}_t = 100 \times \frac{\text{Smoothed +DM}_t}{\text{Smoothed TR}_t}$$

$$\text{-DI}_t = 100 \times \frac{\text{Smoothed -DM}_t}{\text{Smoothed TR}_t}$$

### B. Step 2: DMI Oscillator

An oscillator is created from the difference between the two directional indicators:

$$\text{DMI Oscillator}_t = \text{+DI}_t - \text{-DI}_t \quad \text{(OSC\_PDI\_MINUS\_NDI mode)}$$

### C. Step 3: Kaufman's Efficiency Ratio (ER) & Adaptive Period (NSP) *(Adaptive Version Only)*

The Efficiency Ratio is calculated on the `DMI Oscillator` line over lookback $E$ (`InpErPeriod`):

$$\text{Direction}_t = |\text{DmiOsc}_t - \text{DmiOsc}_{t-E}|$$

$$\text{Volatility}_t = \sum_{j=0}^{E-1} |\text{DmiOsc}_{t-j} - \text{DmiOsc}_{t-j-1}|$$

$$\text{ER}_t = \frac{\text{Direction}_t}{\text{Volatility}_t} \quad \text{clamped between } 0.0 \text{ and } 1.0$$

The Adaptive Stochastic Period (NSP) is calculated as a linear interpolation between `InpMinStochPeriod` ($N_{\text{min}}$) and `InpMaxStochPeriod` ($N_{\text{max}}$):

$$\text{NSP}_t = \text{ER}_t \times (N_{\text{max}} - N_{\text{min}}) + N_{\text{min}}$$

### D. Step 4: Stochastic Normalization and Smoothing

* **Standard Version:** The raw $\%K$ is calculated over the fixed period $K$ (`InpFastKPeriod`) of the DMI Oscillator.
* **Adaptive Version:** The raw $\%K$ is calculated over the dynamically changing period $\text{NSP}_t$ of the DMI Oscillator.

$$\%K_{\text{raw}, t} = 100 \times \frac{\text{DmiOsc}_t - \min(\text{DmiOsc}_{t \dots t-K+1})}{\max(\text{DmiOsc}_{t \dots t-K+1}) - \min(\text{DmiOsc}_{t \dots t-K+1})}$$

* **Slow %K (Main Line):** Raw $\%K$ smoothed over `InpSlowKPeriod` using `InpStochMethod`:
  $$\%K_{\text{slow}, t} = \text{MA}(\%K_{\text{raw}}, P_{\text{slow}}) \quad \text{using selected MA Type}$$
* **Signal %D (Signal Line):** Slow $\%K$ smoothed over `InpSmoothPeriod` using `InpSignalMethod`:
  $$\%D_t = \text{MA}(\%K_{\text{slow}}, P_{\text{sig}}) \quad \text{using selected MA Type}$$

---

## 3. Advanced MQL5 MTF Implementation Details

### A. Forming LTF Block Flat-Force (The Warping Solution)

MTF separate-window indicators often suffer from visual warping (the live-bar warping bug where only the very last LTF bar gets updated, creating a jagged, diagonal line across the active HTF block). The suite resolves this by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

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

By forcing a full-block rewrite on every live tick, the active HTF step (both $\%K$ and $\%D$ lines) remains perfectly flat and responsive in real-time, matching institutional charting standards.

### B. Strict Non-Repainting State Safety on MTF Live Ticks (State Mocking)

Welles Wilder's smoothing equations (+DM, -DM, TR), Kaufman's Efficiency Ratio, and subsequent MA/VWMA slowing engines are highly stateful. To support real-time updating without modifying closed historical states (which would cause severe repainting and backtesting discrepancies), the MTF indicators utilize a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator).

This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting, double-accumulating, or corrupting any historical states inside the recursive registers, preventing the Double-Accumulation Bug completely.

### C. Dynamic Volume-Type Auto-Routing Pipeline

To support volume-weighted types (like **VWMA**) for the slowing or signal lines, the calculator classes have been overloaded with volume-based `Calculate` signatures. Both standard and MTF indicators query `SYMBOL_VOLUME_LIMIT` to detect if the broker provides Real Volume.

* If real volume is available (e.g. Stocks, Futures, Crypto), the engine automatically initializes the calculators to use **`VOLUME_REAL`** and pull HTF real volumes (`CopyRealVolume`).
* If only tick volume is available (e.g. Forex, CFD), the engine automatically falls back to **`VOLUME_TICK`** and pull HTF tick volumes (`CopyTickVolume`).
This makes the DMI Stochastic suite completely robust, universal, and fully automated across all financial instruments.

### D. Asynchronous Timer Guard

A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 4. Parameters

### A. Timeframe Settings (MTF Version Only)

* **Target Timeframe (`InpUpperTimeframe`):** The target higher timeframe to calculate DMI Stochastic on (Default: `PERIOD_H1`).

### B. Core DMI Settings

* **Candle Source (`InpCandleSource`):** Selects the candle type for the initial DMI calculation (Standard or Heikin Ashi). Default: `CANDLE_STANDARD`.

* **Oscillator Formula (`InpOscType`):** Select between `OSC_PDI_MINUS_NDI` (intuitive bullish bias) or `OSC_NDI_MINUS_PDI` (original bearish bias).
* **DMI Period (`InpDMIPeriod`):** The lookback period for +DI and -DI. (Default: `10`).

### C. Adaptive Lookback Settings *(Adaptive Version Only)*

* **Efficiency Ratio Period (`InpErPeriod`):** Lookback window to measure DMI Oscillator efficiency (Default: `10`).

* **Minimum Stochastic Period (`InpMinStochPeriod`):** The lower bound of the adaptive Stochastic lookback (Default: `5`).
* **Maximum Stochastic Period (`InpMaxStochPeriod`):** The upper bound of the adaptive Stochastic lookback (Default: `30`).

### D. Stochastic & Smoothing Settings

* **Stochastic %K Period (`InpFastKPeriod` - Standard Version Only):** Lookback window for %K. (Default: `10`).

* **Stochastic %K Slowing (`InpSlowKPeriod`):** Smooths the raw %K into the Slow %K line (Default: `3`).
* **MA Method for %K (`InpStochMethod` / `InpSlowingMAType`):** Select the MA type for %K slowing, fully supporting VWMA (Default: `SMA`).
* **Stochastic %D Period (`InpSmoothPeriod` / `InpDPeriod`):** Smooths the main %K line to create the signal line (Default: `3`).
* **MA Method for %D (`InpSignalMethod` / `InpDMAType`):** Select the MA type for %D smoothing, fully supporting VWMA (Default: `SMA`).

---

## 5. Usage and Interpretation

The DMI Stochastic should be interpreted as a **momentum-of-momentum** oscillator, representing when the directional pressure (trend impulse) is cyclically overextended. (Assuming default `PDI - NDI` formula).

* **Overbought/Oversold Momentum:**
  * **Values > 80 (Overbought):** Indicates that bullish trend pressure has reached extreme exhaustion. Prepare for a bearish pullback or consolidation.
  * **Values < 20 (Oversold):** Indicates that bearish trend pressure has reached extreme exhaustion. Prepare for a bullish pullback or consolidation.
* **Crossovers:**
  * When the **%K line (blue) crosses above the %D line (red)**, it signals a bullish shift in directional momentum.
  * When the **%K line (blue) crosses below the %D line (red)**, it signals a bearish shift in directional momentum.

### E. Top-Down Macro Cyclical Filter (MTF Strategy)

1. **Macro Trend-Momentum Filter (H1/H4):** Apply `DMIStochastic_MTF_Pro` or `DMIStochastic_Adaptive_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **The Filter:** Only seek buy setups on the lower timeframe if the macro **H1 DMI Stochastic %K** is rising or crossed above the %D signal line below the 50 centerline.
3. **Execution:** Drop down to the lower M5 chart. Execute long trades when local LTF momentum shifts, avoiding counter-trend positions. If H1 MTF DMI Stochastic is deeply overbought ($> 80$), freeze all long breakouts and prepare to lock in profits, as macro-level trend-momentum has reached climatic exhaustion.
