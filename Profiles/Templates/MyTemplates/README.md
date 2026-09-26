# Chart Templates (`MyTemplates/`)

A standardized set of chart templates (`.tpl`) for market analysis. Each
template is a pre-configured workspace designed for a specific trading style or
analytical purpose. The collection is documented in `TEMPLATE_REGISTRY.md`
(indicator sets, renames, and decisions, dated).

## Folder Structure

- **`Strategies/`** – Active trading setups (`strategy.` prefix).
- **`Demos/`** – Indicator showcase templates (`demo.` prefix).
- **`Archive/`** – Obsolete / unused templates kept for reference.
- **`Common/`** – Shared base templates (`Default.tpl`, `Tester.tpl`) used as
  safe baselines for the Strategy Tester and chart reset.
- **`Experiments/`** – Experimental / scratch layouts (`test_layout*.tpl`) that
  are not part of the reviewed catalogue.

## Naming Convention

```text
[Prefix].[ChartType].[System].[Session].[Variation].tpl
```

### `[Prefix]` — folder / purpose

| Token | Meaning |
| :--- | :--- |
| `strategy` | Active trading strategy (stored in `Strategies/`) |
| `demo` | Indicator showcase (stored in `Demos/`) |
| *(omitted)* | Legacy templates that still use the old `[Focus]`-style names |

> **Style tag retired:** the former `[Focus]` token (`trend`, `scalp`, `sr`,
> `reversal`, …) is no longer part of the file name. The style/goal of each
> strategy is tracked in `TEMPLATE_REGISTRY.md` (the `Fókusz` column) instead.
> Existing legacy files are migrated to the `strategy.` prefix progressively.

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
| `absorption_mtf` | Absorption MTF Pro (multi-timeframe) |
| `slope` | Laguerre Slope |
| `accel` | Laguerre Accel |
| `murrey` | Murrey_Math_Line_X |
| `murrey_sessions` | Murrey + session analysis set |
| `murrey_momentum` | Murrey + momentum setup |
| `ss` | SuperSmoother (Ehlers) |
| `supersmoother` | SuperSmoother (Ehlers) family (e.g. `supersmoother.macd`) |
| `dualsmoother` | Dual Smoother setup |
| `dsma` | DSMA (Ehlers) |
| `momentum` | Momentum setup (e.g. `dsma_momentum`) |
| `vwap` | VWAP indicator |
| `vbands` | VWAP Bands Pro |
| `vwap_bands` | VWAP + VWAP Bands Pro (tsi family) |
| `vwap_levels` | VWAP History Levels |
| `vhist` | VWAP_History_Levels (historical session VWAP levels) |
| `vpres` | VolumePressure_Pro |
| `vel` | Velocity |
| `stocha` | Stoch Adaptive |
| `stochadmi` | StochAdaptiveDMI |
| `stochrsi` | StochRSI Slow (StochRSI_Slow_Pro) |
| `smi` | SMI (SMI_Pro) |
| `escore` | E-Score Pro set (E-Score + VScore widget) |
| `vscore` | V-Score Bands |
| `sessions` | Session Analysis Single set (4 session indicators) |
| `laguerre` | Laguerre filter |
| `laguerre_fibo` | Laguerre + Fibonacci parameter pair |
| `laguerre_macd` | Laguerre + MACD |
| `lscore` | LScore |
| `lstoch` | Laguerre Stoch |
| `rsi` | Laguerre RSI |
| `fisher` | Fisher Transform |
| `fibo` | Fibonacci parameter pair (e.g. 0.500 / 0.236) |
| `tsi` | TSI Combo |
| `tsi_rvol` | TSI Combo + RVOL |
| `tsi_sqz` | TSI Combo + Squeeze |
| `tsi_vwap_bands` | TSI Combo + VWAP + bands |
| `sqz` | Squeeze (BB + KC) |
| `rvol` | Relative Volume (RVOL) |
| `linreg` | Linear Regression widget + R2 + Slope |
| `macd` | MACD Pro |
| `macd_kama` | MACD + KAMA |
| `madh` | MADH (Ehlers) |
| `polyreg` | Polynomial Regression |
| `keltner` | Keltner Channel |
| `kama` | KAMA |
| `pivot` | PivotPoints_Pro (unified; replaces broker-specific `gpivot`/`tpivot`) |

> **`pivot` note:** since the PivotPoints_Pro unification, all pivot setups use
> the unified `pivot` token (the broker-specific `gpivot`/`tpivot` tokens are
> retired). New-gen pivot setups typically use `PivotPro(PERIOD_H4)` or
> `PivotPro(PERIOD_D1)` alongside VWAP Bands / V-Score Bands.

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
>
> **Legacy session tokens:** older templates use the previous convention where
> `tlx` = TSE + LSE + XETRA (no NYSE) and `lxn` = LSE + XETRA + NYSE (no TSE),
> e.g. `scalp.ha.vwap.tlx_win.full_v2.tpl`, `trend.ha.laguerre.lxn.suite_v1.tpl`.
> New templates use the full four-session `tlxn_*` tokens above.

### `[Variation]` (optional)

| Token | Meaning |
| :--- | :--- |
| `base` | Base / root variant (e.g. `adx_dmi.base`) |
| `full` | Full indicator set (e.g. `tsi.full`) |
| `suite` | Indicator suite setup (e.g. `laguerre.suite`) |
| `light` | Lightweight / reduced setup (e.g. `murrey_momentum.light`) |
| *(omitted)* | When there is no special variation |

> The former `v1`/`v2` version markers were removed: functional differences
> are now expressed with descriptive tokens (e.g. `lxn_sum_short`,
> `stochadmi`). Some archived legacy templates still carry `v1`/`v2` markers.

## Examples

| Template | Interpretation |
| :--- | :--- |
| `strategy.ha.adx_dmi_murrey_vwap_ss.tlxn_sum.tpl` | strategy / HA / ADX+DMI+Murrey+VWAP+SS / tlxn summer |
| `strategy.ha.murrey_stochrsi_smi.tlxn_sum.tpl` | strategy / HA / Murrey + StochRSI + SMI / tlxn summer |
| `strategy.ha.adx_dmi_murrey_vbands_ss_vel.tlxn_sum.tpl` | strategy / HA / ADX+DMI+Murrey+VWAP Bands+SS+Velocity |
| `strategy.ha.adx_dmi_pivot_vbands_ss_vel_stocha.lxn_sum_short.tpl` | strategy / HA / ADX+DMI+PivotPro+VWAP Bands+SS+Velocity+Stoch / shortened lxn |
| `strategy.std.tsi_pivot_vbands.tpl` | strategy / std / TSI + PivotPro (D1) + V-Score Bands |
| `strategy.std.tsi_pivot_vbands_vhist.tpl` | strategy / std / TSI + PivotPro + V-Score Bands + VWAP Hist |
| `demo.ha.sessions.tlxn_sum.tpl` | demo / HA / session analysis (tlxn summer) |
| `demo.std.macd.tpl` | demo / std / MACD Pro showcase |

> Not all strategy templates are migrated yet: legacy names with the old
> `trend.` / `scalp.` / `sr.` prefixes still exist in `Strategies/` and are
> being renamed to the `strategy.` prefix progressively.

## Demo Templates (`Demos/`)

`demo.{charttype}.{system}.tpl` – showcases a single indicator or indicator pair
cleanly, without a trading setup.

| Template | Showcased indicator(s) |
| :--- | :--- |
| `demo.ha.base.tpl` | Heikin Ashi base chart (no indicators) |
| `demo.ha.sessions.tlxn_sum.tpl` | HA chart + session analysis (tlxn summer) |
| `demo.ha.sessions.tlxn_win.tpl` | HA chart + session analysis (tlxn winter) |
| `demo.std.adx_dmi.tpl` | ADX Pro + DMI Stoch |
| `demo.std.escore.tpl` | Ehlers smoother + E-Score |
| `demo.std.linreg.tpl` | LinReg widget + R2 + Slope |
| `demo.std.lscore.tpl` | Laguerre Filter + LScore |
| `demo.std.macd.tpl` | MACD Pro (with EMA basis) |
| `demo.std.macd_kama.full.tpl` | MACD + KAMA |
| `demo.std.madh.full.tpl` | MADH (Ehlers) |
| `demo.std.polyreg.full.tpl` | Polynomial Regression |
| `demo.std.sessions.lxn_sum_short.tpl` | lxn short session configuration |
| `demo.std.sessions.tlxn_interim-march.tpl` | tlxn interim-march session configuration |
| `demo.std.sessions.tlxn_sum.tpl` | tlxn summer session configuration |
| `demo.std.sessions.tlxn_win.tpl` | tlxn winter session configuration |
| `demo.std.squeeze.tpl` | Squeeze (BB + KC) |
| `demo.std.supersmoother.macd.tpl` | SuperSmoother + MACD |
| `demo.std.tsi.tpl` | TSI Combo |
| `demo.std.vscore_dual_widget.tpl` | Dual VScore widget (M15 + H1) |
| `demo.std.vscore_widget.tpl` | Solo VScore widget |
| `demo.std.vwap_levels.tpl` | VWAP History Levels |

## Maintenance

- The collection state is tracked in **`TEMPLATE_REGISTRY.md`**: every template
  with its indicator set, status (`felülvizsgálva` = reviewed,
  `döntés függőben` = decision pending, `átnevezésre vár` = awaiting rename,
  `archiválva` = archived, `törölve` = deleted) and a dated decision log.
- When adding a new template: name it according to the convention, then record
  it in the registry together with its indicator set.
