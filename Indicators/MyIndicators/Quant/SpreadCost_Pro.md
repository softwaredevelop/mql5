# Spread Cost Pro (Indicator)

## 1. Summary

**Spread Cost Pro** is a risk management utility that visualizes the "Real Cost of Trading" dynamically. It doesn't just show the spread in points (which is often meaningless in isolation), but calculates the spread as a **percentage of the current market volatility (ATR)**.

This helps traders answer the question: *"Is it worth entering a trade right now, or is the spread too wide relative to the potential profit?"*

## 2. Methodology

$$Cost \% = \left( \frac{\text{Spread}}{\text{ATR}} \right) \times 100$$

* **Spread:** The difference between Bid and Ask at that historical moment.
* **ATR:** The average range of price movement (potential profit space).

## 3. Usage

* **Green Bars (< 10%):** **High Liquidity / Cheap.** This is the ideal time to scalp. The market is moving enough that the spread is negligible.
* **Red Bars (> 30%):** **Low Liquidity / Expensive.** The spread is eating up a huge portion of the potential move.
  * *Warning:* This often happens during **News Events**, **Market Rollover (23:00)**, or on **Exotic Pairs**.
  * *Action:* **DO NOT SCALP.** Only enter long-term Swing trades where the spread matters less, or wait for liquidity to return.
