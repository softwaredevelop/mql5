# Market Scanner Pro (Script)

## 1. Summary (Introduction)

**Market Scanner Pro** is an "Ultra-High Frequency" quantitative analysis tool designed to bridge the gap between technical charting and AI-assisted trading. It generates the **"QuantScan 9.0"** dataset, a dense CSV report containing over 30 institutional-grade metrics for every asset in your watchlist.

Unlike standard screeners, this tool analyzes the **structure, stability, and statistical anomalies** of the price action, not just simple indicator crossovers.

## 2. The 3-Layer Fractal Model

To provide a complete market X-Ray, metrics are calculated across three synchronized timeframes:

1. **Layer 1: Context (H1):** Determines the Strategic Direction. Is the market trending or ranging? Is the move efficient?
2. **Layer 2: Flow (M15):** Determines the Tactical State. Is price cheap or expensive (Value)? Is momentum sustaining?
3. **Layer 3: Trigger (M5):** Determines the Execution Timing. Is there immediate velocity and volume support?

## 3. The "QuantScan 9.0" Dataset (Column Dictionary)

The CSV output contains the following metrics. Use this legend to interpret the data or guide your LLM.

### A. Global Sentiment (Header)

* **Format:** `RISK-ON (US:+0.5% DX:-0.3%)`.
* **Logic:** Compares S&P 500 vs Dollar Index.
  * **Risk-On:** Stocks Up, Dollar Down (Bullish for Crypto/EURUSD).
  * **Risk-Off:** Stocks Down, Dollar Up (Bearish).

### B. Layer 1: H1 Context (Strategy)

| Metric | Full Name | Interpretation |
| :--- | :--- | :--- |
| **ALPHA** | Alpha Excess Return | True performance adjusted for market risk. |
| **BETA** | Beta Sensitivity | `>1.5`: Aggressive/Volatile. `<0.5`: Defensive. |
| **VHF** | **Vertical Horizontal Filter** | Trend Intensity. `>0.40`: Trending. `<0.30`: Ranging. |
| **R2** | **R-Squared** | Trend Linearity. `>0.7`: Perfect straight line. `<0.3`: Random mess. |
| **ZONE** | Market Structure | Murrey Math Level. `Extreme` areas imply reversal risk. |

### C. Layer 2: M15 Flow (Tactics)

| Metric | Full Name | Interpretation |
| :--- | :--- | :--- |
| **V_SCORE** | **VWAP Z-Score** | Deviation from VWAP. `>2.0`: Expensive. `< -2.0`: Cheap (Value). |
| **AUTOCORR** | **Lag-1 Autocorrelation** | Regime filter. `>0`: Momentum. `<0`: Mean Reversion (Ping-pong). |
| **VOL_REGIME** | Volatility Regime | `>1.0`: Expansion (Impulse). `<1.0`: Contraction (Rest). |
| **SQZ** | Volatility Squeeze | `ON`: Potential explosive move building up. |
| **SQZ_MOM** | Squeeze Momentum | Direction and strength of the potential breakout. |
| **VHF** | **Vertical Horizontal Filter** | Trend Intensity. `>0.40`: Trending. `<0.30`: Ranging. |
| **R2** | **R-Squared** | Trend Linearity. `>0.7`: Perfect straight line. `<0.3`: Random mess. |
| **DIST_PDH/L** | Distance Prev High/Low | Space to key daily levels (ATR units). |

### D. Layer 3: M5 Trigger (Execution)

| Metric | Full Name | Interpretation |
| :--- | :--- | :--- |
| **VEL** | **velocity** | Signed Speed. `>1.0`: Fast Rally. `<-1.0`: Fast Drop. |
| **VOL_THRUST** | Volume Thrust | Ratio of M5/M15 RVOL. `>1.5`: Accelerating volume. |
| **COST_ATR** | Spread Cost | `>0.3`: Expensive spread (Low liquidity). |

### E. Composites (Decision Support)

| Metric | Full Name | Interpretation |
| :--- | :--- | :--- |
| **ABSORPTION** | Institutional Absorption | `YES`: High Volume + Small Candle = Hidden Reversal. |
| **MTF_ALIGN** | Timeframe Alignment | `FULL_BULL` = H1, M15, and M5 cycles agree. High probability. |

## 4. How to Analyze (LLM Prompts)

### **Scenario 1: The "Unstoppable Trend"**
>
> *"Find assets where `R2_H1 > 0.7` AND `VHF_H1 > 0.4` (Strong Linear Trend). Ensure `MTF_ALIGN` is FULL_BULL and `M15_AUTOCORR` is positive (Momentum regime)."*

### **Scenario 2: The "Value Reversal"**
>
> *"Find assets where `V_SCORE_M15 < -2.0` (Cheap vs VWAP) AND `REV_PROB > 70%`. Check if `ABSORPTION` is YES."*

### **Scenario 3: The "Squeeze Breakout"**
>
> *"Find assets where `SQZ_M15` is ON (or recently broke out) AND `VEL_M5` is spiking (>1.0) with High `RVOL`."*
