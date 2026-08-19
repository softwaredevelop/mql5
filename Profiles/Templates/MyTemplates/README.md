# Chart Templates (`MyTemplates/`)

A standardized set of chart templates (`.tpl`) for market analysis. Each
template is a pre-configured workspace designed for a specific trading style or
analytical purpose. The collection is documented in `TEMPLATE_REGISTRY.md`
(indicator sets, renames, and decisions, dated).

## Folder Structure

- **`Strategies/`** – Active trading setups (descriptive, reviewed names).
- **`Demos/`** – Indicator showcase templates (`demo.` prefix).
- **`Archive/`** – Obsolete / unused templates kept for reference.

## Naming Convention

```text
[Focus].[ChartType].[System].[Session].[Variation].tpl
```

### `[Focus]` — trading style / goal

| Token | Meaning |
| :--- | :--- |
| `trend` | Trend-following strategies |
| `reversal` | Mean-reversion / reversal detection |
| `sr` | Support/resistance and structural analysis |
| `scalp` | Short-term, intraday strategies |
| `demo` | Indicator showcase (stored in `Demos/`) |

### `[ChartType]` — base chart visualization

| Token | Meaning |
| :--- | :--- |
| `std` | Standard candlesticks |
| `ha` | Heikin Ashi candles |

### `[System]` — the core of the setup (underscore-joined token chain)

Tokens describe the indicator stack. Main token glossary:

| Token | Indicator / meaning |
| :--- | :--- |
| `adx_dmi` | ADX Pro + DMI Stoch |
| `absorption` | Absorption Pro |
| `murrey` | Murrey_Math_Line_X |
| `ss` | SuperSmoother (Ehlers) |
| `vwap` | VWAP indicator |
| `vbands` | VWAP Bands Pro |
| `vwap_bands` | VWAP + VWAP Bands Pro (tsi family) |
| `vel` | Velocity |
| `stocha` | Stoch Adaptive |
| `stochadmi` | StochAdaptiveDMI |
| `escore` | E-Score Pro set (E-Score + VScore widget) |
| `vscore` | V-Score Bands |
| `sessions` | Session Analysis Single set (4 session indicators) |
| `laguerre` | Laguerre filter |
| `lscore` | LScore |
| `lstoch` | Laguerre Stoch |
| `rsi` | Laguerre RSI |
| `fibo` | Fibonacci parameter pair (e.g. 0.500 / 0.236) |
| `tsi` | TSI Combo |
| `sqz` | Squeeze (BB + KC) |
| `gpivot` / `tpivot` | Broker pivot: Go Markets / Tickmill |
| `keltner` / `ema` / `macd` / `kama` / `madh` / `polyreg` | Other indicators |

### `[Session]` (optional) — session configuration

Tokens encode the combination of market sessions and daylight-saving state
(`Session_Analysis_Single` indicator):

| Token | Combination | Daylight saving |
| :--- | :--- | :--- |
| `tlxn_sum` | TSE + LSE + XETRA + NYSE | Summer (only TSE marked) |
| `tlxn_win` | TSE + LSE + XETRA + NYSE | Winter (only TSE marked) |
| `tlxn_interim-march` | TSE + LSE + XETRA + NYSE | Transition (LSE/XETRA: interim-march) |
| `lxn_sum_short` | LSE + XETRA + NYSE (no TSE) | Shortened ranges (broker 16:35–22:55) |

> **`short` definition:** the broker's trading range is shorter than the full
> market session range (typically 16:35–22:55 broker time). In this case the
> TSE range is omitted, and the LSE/XETRA/NYSE ranges use shortened variants.
>
> **`interim-march` definition:** the US and EU daylight-saving transitions do
> not happen at the same time; these ranges are optimized for the March
> transition period.

### `[Variation]` (optional)

| Token | Meaning |
| :--- | :--- |
| `base` | Base / root variant (e.g. `adx_dmi.base`) |
| `full` | Full indicator set (e.g. `tsi.full`) |
| `suite` | Indicator suite setup (e.g. `laguerre.suite`) |
| *(omitted)* | When there is no special variation |

> The former `v1`/`v2` version markers were removed: functional differences
> are now expressed with descriptive tokens (e.g. `lxn_sum_short`,
> `stochadmi`).

## Examples

| Template | Interpretation |
| :--- | :--- |
| `trend.ha.adx_dmi.base.tpl` | trend / HA / ADX+DMI base variant, no sessions |
| `trend.ha.adx_dmi_murrey_ss_vwap.tlxn_sum.tpl` | trend / HA / ADX+DMI+Murrey+SS+VWAP / tlxn summer session |
| `trend.ha.adx_dmi_murrey_ss_vwap_vbands_vel_stocha.lxn_sum_short.tpl` | + VWAP Bands + Velocity + Stoch Adaptive / shortened lxn session |
| `scalp.ha.sessions.tlxn_sum.tpl` | scalp / HA / 4 session indicators / tlxn summer |
| `sr.std.murrey_sessions.tlxn_win.full.tpl` | sr / std / Murrey + sessions / tlxn winter |
| `demo.std.macd.tpl` | indicator showcase: MACD Pro |

## Demo Templates (`Demos/`)

`demo.std.{system}.tpl` – showcases a single indicator or indicator pair
cleanly, without a trading setup.

| Template | Showcased indicator(s) |
| :--- | :--- |
| `demo.std.adx_dmi.tpl` | ADX Pro + DMI Stoch |
| `demo.std.escore.tpl` | Ehlers smoother + E-Score |
| `demo.std.lscore.tpl` | Laguerre Filter + LScore |
| `demo.std.linreg.tpl` | LinReg widget + R2 + Slope |
| `demo.std.macd.tpl` | MACD Pro (with EMA basis) |
| `demo.std.squeeze.tpl` | Squeeze (BB + KC) |
| `demo.std.vscore_widget.tpl` | Solo VScore widget |
| `demo.std.vscore_dual_widget.tpl` | Dual VScore widget (M15 + H1) |
| `demo.std.sessions.lxn_sum_short.tpl` | lxn short session configuration |

## Maintenance

- The collection state is tracked in **`TEMPLATE_REGISTRY.md`**: every template
  with its indicator set, status (`felülvizsgálva` = reviewed,
  `döntés függőben` = decision pending, `átnevezésre vár` = awaiting rename,
  `archiválva` = archived, `törölve` = deleted) and a dated decision log.
- When adding a new template: name it according to the convention, then record
  it in the registry together with its indicator set.
