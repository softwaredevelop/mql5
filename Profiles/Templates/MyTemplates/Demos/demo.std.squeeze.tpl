<chart>
symbol=EURUSD
period_type=0
period_size=15
digits=5
tick_size=0.000000
position_time=0
scale_fix=0
scale_fixed_min=0.000000
scale_fixed_max=0.000000
scale_fix11=0
scale_bar=0
scale_bar_val=1.000000
scale=4
mode=1
fore=0
grid=0
volume=0
scroll=1
shift=1
shift_size=10
fixed_pos=0.000000
ticker=1
ohlc=1
one_click=0
one_click_btn=1
bidline=1
askline=1
lastline=0
days=0
descriptions=0
tradelines=1
tradehistory=0
window_left=0
window_top=0
window_right=0
window_bottom=0
window_type=1
floating=0
floating_left=0
floating_top=0
floating_right=0
floating_bottom=0
floating_type=1
floating_toolbar=1
floating_tbstate=
background_color=16777215
foreground_color=0
barup_color=0
bardown_color=0
bullcandle_color=16777215
bearcandle_color=0
chartline_color=0
volumes_color=32768
grid_color=12632256
bidline_color=12632256
askline_color=17919
lastline_color=12632256
stops_color=17919
windows_total=1

<window>
height=100.000000
objects=0

<indicator>
name=Main
path=
apply=1
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=0
fixed_height=-1
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Bollinger_Bands_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=4
fixed_height=-1

<graph>
name=Upper Band
draw=1
style=2
width=1
color=2330219
</graph>

<graph>
name=Lower Band
draw=1
style=2
width=1
color=2330219
</graph>

<graph>
name=Centerline
draw=1
style=0
width=1
color=2330219
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Bollinger Bands Core Settings ---=
InpPeriod=21
InpDeviation=2.0
InpMAType=0
InpSourcePrice=1
--- Visual Settings - Centerline ---=
InpColorMiddle=2330219
InpStyleMiddle=0
InpWidthMiddle=1
--- Visual Settings - Outer Bands ---=
InpColorBands=2330219
InpStyleBands=2
InpWidthBands=1
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\KeltnerChannel_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=4
fixed_height=-1

<graph>
name=Upper Band
draw=1
style=2
width=1
color=17919
</graph>

<graph>
name=Lower Band
draw=1
style=2
width=1
color=17919
</graph>

<graph>
name=Basis
draw=1
style=0
width=1
color=17919
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Middle Line (MA) Settings ---=
InpMaPeriod=21
InpMaMethod=1
InpSourcePrice=6
--- Channel (ATR) Settings ---=
InpAtrPeriod=13
InpMultiplier=1.5
InpAtrSource=0
--- Visual Settings - Centerline (Basis) ---=
InpColorMiddle=17919
InpStyleMiddle=0
InpWidthMiddle=1
--- Visual Settings - Outer Bands ---=
InpColorBands=17919
InpStyleBands=2
InpWidthBands=1
</inputs>
</indicator>
</window>

<window>
height=30.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Quant\Squeeze_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=-1731.197675
scale_fix_max=0
scale_fix_max_val=2337.972155
expertmode=4
fixed_height=-1

<graph>
name=Momentum
draw=11
style=0
width=2
color=16436871,16760576,17919,5275647
</graph>

<graph>
name=Squeeze State
draw=12
style=0
width=2
arrow=159
color=65280,255
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Squeeze Core Settings ---=
InpPeriod=21
InpBBMult=2.0
InpKCMult=1.5
InpSourcePrice=1
--- Momentum Settings (Linear Regression) ---=
InpMomPeriod=13
--- Visual Settings - Momentum Histogram ---=
InpColorBullExp=16436871
InpColorBullDec=16760576
InpColorBearExp=17919
InpColorBearDec=5275647
--- Visual Settings - Squeeze Dots ---=
InpColorSqzOff=65280
InpColorSqzOn=255
InpDotSize=2
</inputs>
</indicator>
</window>
</chart>
