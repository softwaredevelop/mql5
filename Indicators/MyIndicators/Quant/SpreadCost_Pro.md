# Institutional Spread Cost Pro Detector (Standard & MTF-Ready)

## 1. Summary (Introduction)

The **Institutional Spread Cost Pro Detector** is an essential quantitative transaction-friction and execution-feasibility tool. It displays the bid-ask spread not as a static, meaningless point value, but as a **dynamic percentage of the immediate market volatility (ATR)**.

In systematic and high-frequency trading, transaction cost is the single largest drag on strategy performance. A $1.5$-point spread might look cheap on paper, but if the average trading range (ATR) of a 5-minute bar is only $5.0$ points, that spread represents a staggering **$30\%$ transaction friction**. Attempting to scalp in this environment is mathematically unviable, as transaction costs will rapidly devour any statistical expectancy.

By normalizing the live spread against the Average True Range (ATR), the `SpreadCost_Pro` indicator acts as an objective **Go/No-Go Execution Filter**. It categorizes execution environments into three logical, color-coded zones:

* **Cheap / Highly Viable (Green):** Spread cost represents $\le 10\%$ of the immediate volatility. Optimal scalp execution environment.
* **Normal / Acceptable (Silver):** Spread cost is between $10\%$ and $30\%$ of volatility. Standard trading environment.
* **Expensive / High-Risk (Crimson):** Spread cost is $\ge 30\%$ of volatility. Execution should be blocked due to extreme transaction friction.

---

## 2. Mathematical & Quant Foundations

The indicator normalizes integer spread values against the price-expressed Average True Range (ATR):

### A. Volatility Baseline (ATR)

First, raw volatility is calculated using the standard 14-period Wilder's smoothed ATR:

$$\text{TR}_t = \max \big( (H_t - L_t), |H_t - C_{t-1}|, |L_t - C_{t-1}| \big)$$

$$\text{ATR}_t = \frac{\text{ATR}_{t-1} \times (N - 1) + \text{TR}_t}{N}$$

### B. Spread Price Conversion

The integer spread array provided by MT5 (`spread[]`) is expressed in points. To compare it to the ATR, it is converted into a decimal price value using the symbol's point size:

$$\text{SpreadPrice}_t = \text{SpreadPoints}_t \times \text{Point}$$

### C. Spread Cost Ratio Formula

The final Spread Cost percentage representing the transaction friction on each bar $t$ is calculated as:

$$\text{SpreadCostRatio}_t = \frac{\text{SpreadPrice}_t}{\text{ATR}_t} \times 100.0$$

Where $\text{ATR}_t > 1.0e-9$ to prevent division-by-zero exceptions.

### D. Multi-Template Visual Classification

Each calculated percentage is mapped to a premium-grade color index inside the color histogram:

$$\text{ColorIndex}_t = \begin{cases}
0.0 \quad \text{(Cheap - clrMediumSeaGreen)} & \text{if } \text{SpreadCostRatio}_t \le \text{InpCheapLevel} \\
2.0 \quad \text{(Expensive - clrCrimson)} & \text{if } \text{SpreadCostRatio}_t \ge \text{InpExpensiveLevel} \\
1.0 \quad \text{(Normal - clrSilver)} & \text{otherwise}
\end{cases}$$

---

## 3. Volatility vs. Cost Timeframe Dynamics

Due to the mathematical relationship between spread and volatility, the indicator behaves differently depending on the chosen timeframe:

| Timeframe Category | ATR (Volatility) | Spread (Cost) | Average Cost % | Quant Trading Application |
| :--- | :--- | :--- | :---: | :--- |
| **Lower TF (M1 to M15)** | Ultra-Small | Constant | **High ($20\% - 50\%$)** | **Scalping Filter.** Blocks execution during low-volatility sessions or wide-spread periods. |
| **Medium TF (M30 to H1)** | Moderate | Constant | **Medium ($5\% - 15\%$)** | **Intraday Pivot Verification.** Confirms optimal entry timing on trend pullbacks. |
| **Higher TF (H4 to Daily)** | Very Large | Constant | **Ultra-Low ($<2\%$)** | **Broker Spread Quality Audit.** Primarily used to compare transaction costs across different brokers. |

---

## 4. Visual & Technical Highlights

* **Automatic Subwindow Scaling:**
  By removing rigid minimum scaling boundaries, the indicator separate window dynamically auto-scales, providing an aesthetically pleasing, spacious visual depth for the histogram bars across all template setups.
* **Platform-Aware Chronological Safety:**
  The engine enforces chronological array indexing (`ArraySetAsSeries(..., false)`) across all input prices, timeframes, and indicator buffers, completely eliminating phase shift errors.
* **Live Spread Fallback Guard:**
  During the initial synchronization of custom timeframes (e.g., M3, M10), the historical `spread[]` array may temporarily contain only zeros. To prevent empty chart displays, the engine dynamically intercepts the live broker spread:
  ```mql5
  double sp = (double)spread[i];
  if(i == rates_total - 1 && sp == 0.0 && current_spread > 0)
    {
     sp = (double)current_spread; // Fallback to live broker spread
    }
  ```

  This guarantees immediate visual output on the forming bar as soon as a live tick is received.

---

## 5. Quantitative Trading Applications

### A. Systematic Scalping Go/No-Go Filter

This strategy blocks algorithmic execution when transaction costs are statistically too high relative to immediate market ranges.

1. **System Setup:**
   * Integrate the `SpreadCost_Pro` logic into your EA (Expert Advisor).
   * Define `InpExpensiveLevel = 30.0` (30% transaction friction).
2. **Algorithmic Entry Filter:**
   * Before opening any scalp position (Buy or Sell), query the latest value of the `SpreadCost_Pro` buffer (`BufCost[rates_total-1]`).
   * **BLOCK EXECUTION:** If `BufCost[rates_total-1] >= 30.0`, block the trade signal. The spread is too wide or volatility is too low.
   * **ALLOW EXECUTION:** If `BufCost[rates_total-1] < 30.0`, allow the trade to execute.
3. **Strategic Value:** This filter eliminates unprofitable scalp trades during low-volume sessions (such as the Asian session on GBPUSD or the daily rollover period), saving the portfolio from death by a thousand commission cuts.

### B. Broker Spread Quality Audit

Use the indicator on an H1 chart to compare execution costs between different brokerage firms on the same financial asset.

1. **Setup:**
   * Load the indicator on identical currency pairs across two different trading terminals (Broker A and Broker B).
2. **Analysis:**
   * Observe the ratio of Cheap (Green) vs. Normal (Silver) histogram bars over a 500-bar history.
   * The broker showing a higher frequency of Green bars and lower spikes in Crimson bars has superior liquidity routing and tighter spreads, making them the mathematically optimal choice for systematic execution.
