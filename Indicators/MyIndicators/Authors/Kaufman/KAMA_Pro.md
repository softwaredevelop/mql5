# Kaufman's Adaptive Moving Average (KAMA) Pro (v3.30)

Professional Quantitative Adaptive Filter with Native Multi-Timeframe (MTF) Support

---

## 1. Summary (Introduction)

**Kaufman's Adaptive Moving Average (KAMA)**, designed by quantitative trading pioneer Perry J. Kaufman, is an intelligent, low-lag moving average engineered to solve the classic responsiveness-versus-smoothness dilemma. Standard moving averages force a compromise: short periods produce rapid signals but generate false breakout whipsaws in ranging markets, while long periods eliminate noise but lag significantly during fast trends.

KAMA overcomes this by dynamically adjusting its smoothing coefficient based on the market's **Efficiency Ratio (ER)**:

* **Trending Phase (High Efficiency):** KAMA accelerates dynamically toward the speed of a fast EMA (e.g., 2-period), capturing momentum with minimal lag.
* **Consolidation / Choppy Phase (Low Efficiency):** KAMA decelerates toward the speed of a slow EMA (e.g., 30-period) and flattens out, completely neutralizing market noise.

Our **KAMA Pro (v3.30)** implementation provides a definition-true mathematical engine with unified **Native & Multi-Timeframe (MTF)** processing, full **Heikin Ashi** synthetic price filtering, and incremental $O(1)$ performance.

---

## 2. Mathematical Foundations & Calculation Logic

The foundation of KAMA is the **Efficiency Ratio (ER)**, which acts as a signal-to-noise detector.

```text

                    | Price(t) - Price(t - N) |  (Net Direction / Signal)
ER(t) = ─────────────────────────────────────────────────────────────
         ∑ [ | Price(t - i) - Price(t - i - 1)| ]  (Total Path / Noise)

```

### 2.1. Mathematical Formulation

#### 1. Direction (Signal)

The absolute net price change over the lookback period $N$:
$$\text{Direction}_t = | P_t - P_{t-N} |$$

#### 2. Volatility (Noise)

The total sum of all individual price path segments across the lookback period $N$:
$$\text{Volatility}_t = \sum_{i=0}^{N-1} | P_{t-i} - P_{t-i-1} |$$

#### 3. Efficiency Ratio (ER)

$$\text{ER}_t = \begin{cases} \frac{\text{Direction}_t}{\text{Volatility}_t}, & \text{if } \text{Volatility}_t > 0 \\ 0, & \text{if } \text{Volatility}_t = 0 \end{cases}$$
*(The ER value strictly oscillates between $0.0$ [pure noise / chop] and $1.0$ [perfect directional trend]).*

#### 4. Scaled Smoothing Constant (SSC)

First, the fastest and slowest smoothing factors are determined based on standard exponential constants:
$$\alpha_{\text{fast}} = \frac{2}{F + 1}, \quad\quad \alpha_{\text{slow}} = \frac{2}{S + 1}$$
*where $F = \text{Fast EMA Period}$ (default: 2), and $S = \text{Slow EMA Period}$ (default: 30).*

The dynamic smoothing multiplier is scaled and squared to aggressively penalize noisy market regimes:
$$\text{SC}_t = \left[ \text{ER}_t \cdot (\alpha_{\text{fast}} - \alpha_{\text{slow}}) + \alpha_{\text{slow}} \right]^2$$

#### 5. Recursive KAMA Calculation

Similar to an exponential smoothing filter, KAMA updates recursively using the dynamic $\text{SC}_t$:
$$\text{KAMA}_t = \text{KAMA}_{t-1} + \text{SC}_t \cdot (P_t - \text{KAMA}_{t-1})$$

---

## 3. MQL5 Architecture & Engineering Standards

```text

┌────────────────────────────────────────────────────────┐
│                  KAMA_Calculator.mqh                   │
│   (Core Math Engine - Encapsulated Heikin Ashi Engine) │
└──────────────────────────┬─────────────────────────────┘
                           │ Calculates KAMA Values (O(1))
                           ▼
┌────────────────────────────────────────────────────────┐
│                      KAMA_Pro.mq5                      │
│     (Unified Wrapper: Native Timeframe & MTF Engine)   │
├──────────────────────────┬─────────────────────────────┤
│   Direct Mode (O(1))     │   Synchronized MTF Pipeline │
│   • Current Timeframe    │   • Forming Block Anchor    │
│   • Zero-Overhead Bypass │   • Non-Repainting Step Map │
└──────────────────────────┴─────────────────────────────┘

```

### 3.1. Composition over Inheritance

Rather than maintaining separate derived classes for Heikin Ashi calculations, `CKamaCalculator` embeds `CHeikinAshi_Calculator` directly via composition. All standard and Heikin Ashi price modes (`PRICE_HA_CLOSE`, `PRICE_HA_TYPICAL`, etc.) are processed through a single, type-safe internal pipeline.

### 3.2. High-Performance MTF Framework (2026 Standard)

* **Forming LTF Block Flat-Force (The Staircase Solution):** Prevents real-time step distortion by anchoring the mapping start index (`first_bar_of_forming_htf`) to the very first sub-bar of the active HTF candle. All forming bars update simultaneously on every live tick.
* **Strict Chronological Mapping:** Avoids legacy array-direction flipping (`ArraySetAsSeries(true/false)`) by mapping HTF bar shifts directly using zero-overhead chronological indexing:
  $$\text{htf\_idx} = \text{htf\_rates\_total} - 1 - \text{iBarShift}(\dots)$$
* **Asynchronous Data Guard (`OnTimer`):** A 1-second background timer checks whether higher-timeframe history is synchronized, automatically refreshing the indicator once historical data becomes available.

---

## 4. Parameters Reference

### Timeframe Settings

* `InpTimeframe` (*default: `PERIOD_CURRENT`*): Timeframe for calculation. When set to `PERIOD_CURRENT`, it operates in direct high-speed mode. When set to a higher timeframe (e.g., `PERIOD_H1`, `PERIOD_D1`), it activates the synchronized MTF engine.

### KAMA Core Settings

* `InpErPeriod` (*default: `10`*): The lookback window ($N$) used to calculate price direction and volatility.
* `InpFastEmaPeriod` (*default: `2`*): The fastest smoothing period ($F$) used during strong trends.
* `InpSlowEmaPeriod` (*default: `30`*): The slowest smoothing period ($S$) used during consolidating markets.
* `InpSourcePrice` (*default: `PRICE_CLOSE_STD`*): Price input series. Supports all 7 Standard and 7 Heikin Ashi price representations.

### Visual Settings

* `InpColorKAMA` (*default: `clrCrimson`*): Color of the KAMA plot line.
* `InpStyleKAMA` (*default: `STYLE_SOLID`*): Line style (Solid, Dash, Dot).
* `InpWidthKAMA` (*default: `2`*): Line thickness.

---

## 5. Usage & Trading Interpretation

### 5.1. Trend vs. Consolidation Regime (The "Flat Filter")

* **Rising KAMA:** Strong bullish momentum with high directional efficiency.
* **Falling KAMA:** Strong bearish momentum with high directional efficiency.
* **Horizontal / Flat KAMA:** Market is in a low-efficiency sideways consolidation. Trend-following breakout entries should be avoided during flat regimes.

### 5.2. Dynamic Support & Resistance

In established trending markets, KAMA acts as an adaptive institutional support or resistance line. Pullbacks into a sloping KAMA line offer high-probability entry points with tightly definable invalidation levels.

### 5.3. Multi-Timeframe Alignment

By attaching a higher-timeframe KAMA (e.g., `PERIOD_H4` or `PERIOD_D1`) onto an intraday chart (e.g., `PERIOD_M15`), traders can trade strictly in the direction of the macro trend while avoiding intermediate intraday counter-trend traps.
