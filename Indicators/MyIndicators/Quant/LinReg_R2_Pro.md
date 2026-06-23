# LinReg R-Squared Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **LinReg R-Squared Pro Suite** is an institutional-grade quantitative trend-quality analysis suite comprising two advanced indicators:

* `LinReg_R2_Pro` (Single timeframe separate window oscillator)
* `LinReg_R2_MTF_Pro` (Multi-Timeframe separate window oscillator)

Based on linear regression and the Ordinary Least Squares (OLS) method, this suite calculates the **Coefficient of Determination ($R^2$)** and the **Slope** of a rolling price segment.

Instead of lagging behind price action (like standard moving averages or MACD), the R-Squared suite answers two of the most critical questions in quantitative trading:

1. **Is the current market trending or consolidating?** (Statistical trend integrity).
2. **How fast is the price moving, and in which direction?** (Trend velocity and slope).

Featuring Heikin Ashi smoothing integration and **Forming LTF Block Flat-Force** step-blocking, this suite offers a mathematically pure, zero-lag regime filter for high-frequency or multi-timeframe execution.

---

## 2. Mathematical Foundations and Calculation Logic

The calculator processes a rolling or anchored window of size $N$ (`InpPeriod`) of aligned closing prices $y$ (Standard or Heikin Ashi closes). The independent variable $x$ represents the chronological bar index mapped to $[0, 1 \dots N-1]$:

### A. Linear Regression Slope ($a$ or $\beta$)

The Slope represents the average price change per bar inside the lookback window. It is computed as:

$$\text{Slope} = \frac{N \sum (x y) - \sum x \sum y}{N \sum x^2 - (\sum x)^2}$$

* **$\text{Slope} > 0$:** The regression line is tilted upward, confirming an **Uptrend**.
* **$\text{Slope} < 0$:** The regression line is tilted downward, confirming a **Downtrend**.
* **$\text{Slope} \approx 0$:** The regression line is completely horizontal, confirming a **Flat Range / Chop**.

### B. Coefficient of Determination ($R^2$ / R-Squared)

The R-Squared value measures the percentage of price variance explained by the linear regression model. It evaluates how well the price action fits a perfect straight line:

$$R^2 = \frac{\text{SSR}}{\text{SST}} = \frac{\left(N \sum (x y) - \sum x \sum y\right)^2}{\left[N \sum x^2 - (\sum x)^2\right] \left[N \sum y^2 - (\sum y)^2\right]}$$

* **$R^2 \in [0.0, 1.0]$**
  * **$R^2 \ge 0.70$ (Strong Trend):** The market is in a highly structured, low-noise linear trend.
  * **$R^2 \le 0.30$ (Chop / Noise):** Price action is highly scattered and random. The market has zero structural direction.

---

## 3. The Golden Synergy: $R^2$ vs. Slope

Since R-Squared is a normalized absolute value ($0.0 \dots 1.0$), it measures trend **strength/integrity** but is **directionless**. A vertical crash and a parabolic rally can both yield a perfect $R^2$ of $1.0$.

To achieve true quantitative clarity, `LinReg_R2_MTF_Pro` maps **both** metrics simultaneously:

1. **$R^2 \ge 0.70$ and $\text{Slope} > 0$ (Lime Histogram):** **Persistent Bullish Trend.** The market is climbing steadily with minimal noise. Optimal for Long trend-following strategies.
2. **$R^2 \ge 0.70$ and $\text{Slope} < 0$ (Lime Histogram):** **Persistent Bearish Trend.** The market is falling steadily. Optimal for Short trend-following strategies.
3. **$R^2 \le 0.30$ and any Slope (Gray Histogram):** **Congestion / Range.** Standard range-trading or mean-reversion oscillators (RSI, Stochastic) should be deployed to trade range boundaries.
4. **$R^2 \le 0.30$ and Extreme Slope:** **Climatic Spike (Fakeout).** A sudden news-driven price spike occurred, but the lack of $R^2$ stability warns that this move is volatile and highly likely to fade immediately.

---

## 4. Multi-Timeframe Step Alignment (Flat-Force Algorithm)

### A. The Live-Bar Warping Problem

In standard MTF implementations, updating the indicator separate-window tick-by-tick results in a highly distorted "jagged" or "fűrészfog" shape on the current forming HTF bar. Because standard `OnCalculate` only updates the very last lower timeframe (LTF) index (`rates_total - 1`), the previous LTF bars belonging to the active forming HTF block retain stale historic tick states.

### B. The Forming LTF Block Flat-Force Solution

`LinReg_R2_MTF_Pro` resolves this issue by implementing the **Forming LTF Block Flat-Force** step-alignment algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

```mql5
int first_bar_of_forming_htf = rates_total - 1;
while(first_bar_of_forming_htf > 0 &&
      iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
  {
   first_bar_of_forming_htf--;
  }
first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

if(start > first_bar_of_forming_htf)
   start = first_bar_of_forming_htf;
```

By forcing a full-block rewrite on every live tick, the active HTF step remains perfectly flat and responsive in real-time, matching institutional charting standards.

---

## 5. Parameters

### A. Common Parameters

* **Regression Period (`InpPeriod`):** The lookback window size ($N$) for the OLS calculations (Default: `20`).

* **Strong Trend Level (`InpTrendLevel`):** The $R^2$ threshold to trigger the strong trend transition (Default: `0.70`).
* **Applied Price (`InpSourcePrice`):** The applied price source, supporting Standard and Heikin Ashi price series (Default: `PRICE_CLOSE_STD`).

### B. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate regression states on (Default: `PERIOD_M5`).

---

## 6. Advanced Trading Strategies

### A. Top-Down Macro Regime Filter (MTF Strategy)

Before deploying capital on a lower timeframe trend strategy, execute a macro stability check:

1. Apply `LinReg_R2_MTF_Pro` on an `M1` execution chart, set to monitor the **`PERIOD_H1`** target timeframe.
2. If the H1 MTF histogram is strongly **Lime Green ($R^2 \ge 0.70$)**, check the **`Slope MTF`** value in the Data Window.
3. If `Slope MTF` is **positive**, seek only **BUY** entries on local LTF pullbacks.
4. If `Slope MTF` is **negative**, seek only **SELL** entries on local LTF pullbacks.
5. If the H1 MTF histogram is **Gray ($R^2 \le 0.30$)**, disable trend-following systems entirely and deploy mean-reversion range grid bots.

### B. Trend Exhaustion Divergence

When price action makes a series of new highs, but the R-Squared histogram makes a series of lower highs and begins to drop below `0.70`:

* The trend is losing its mathematical linearity and becoming unstable/volatile.
* *Trading Action:* Tighten stop-losses, trail stops aggressively, or take profits. Expect a major consolidation or trend reversal.
