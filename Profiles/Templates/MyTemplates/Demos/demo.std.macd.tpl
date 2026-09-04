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
path=Indicators\MyIndicators\MovingAverage_Pro.ex5
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
name=EMA(13)
draw=1
style=0
width=1
color=7346457
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Moving Average Core Settings ---=
InpPeriod=13
InpMAType=1
InpSourcePrice=1
--- Visual Settings ---=
InpColorMA=7346457
InpStyleMA=0
InpWidthMA=1
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\MovingAverage_Pro.ex5
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
name=EMA(21)
draw=1
style=0
width=1
color=17919
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Moving Average Core Settings ---=
InpPeriod=21
InpMAType=1
InpSourcePrice=1
--- Visual Settings ---=
InpColorMA=17919
InpStyleMA=0
InpWidthMA=1
</inputs>
</indicator>
</window>

<window>
height=50.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\MACD_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=-0.000348
scale_fix_max=0
scale_fix_max_val=0.000783
expertmode=4
fixed_height=-1

<graph>
name=Histogram
draw=2
style=0
width=1
color=12632256
</graph>

<graph>
name=MACD
draw=1
style=0
width=1
color=16748574
</graph>

<graph>
name=Signal
draw=1
style=0
width=1
color=17919
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- MACD Core Settings ---=
InpFastPeriod=13
InpSlowPeriod=21
InpSignalPeriod=8
InpSourceMAType=1
InpSignalMAType=1
InpSourcePrice=1
--- Visual Settings - MACD Line ---=
InpColorMACD=16748574
InpStyleMACD=0
InpWidthMACD=1
--- Visual Settings - Signal Line ---=
InpColorSignal=17919
InpStyleSignal=0
InpWidthSignal=1
--- Visual Settings - Histogram ---=
InpColorHist=12632256
InpStyleHist=0
InpWidthHist=1
</inputs>
</indicator>
</window>
</chart>
