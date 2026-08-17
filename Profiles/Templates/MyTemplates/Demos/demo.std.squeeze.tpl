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
InpPeriod=21
InpDeviation=2.0
InpMAType=0
InpSourcePrice=1
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
color=3937500
</graph>

<graph>
name=Lower Band
draw=1
style=2
width=1
color=3937500
</graph>

<graph>
name=Basis
draw=1
style=0
width=1
color=3937500
</graph>
<inputs>
Middle Line (MA) Settings=
InpMaPeriod=21
InpMaMethod=1
InpSourcePrice=6
Channel (ATR) Settings=
InpAtrPeriod=13
InpMultiplier=1.5
InpAtrSource=0
</inputs>
</indicator>
</window>

<window>
height=50.000000
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
scale_fix_min_val=0.000000
scale_fix_max=0
scale_fix_max_val=0.000000
expertmode=4
fixed_height=-1

<graph>
name=Momentum
draw=2
style=0
width=2
color=16748574,3937500,16760576,2237106
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
Squeeze Settings=
InpPeriod=21
InpBBMult=2.0
InpKCMult=1.5
InpPrice=1
Momentum Settings=
InpMomPeriod=13
</inputs>
</indicator>
</window>
</chart>
