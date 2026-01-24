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
path=Indicators\MyIndicators\Authors\Ehlers\4_Channels_and_Bands\Laguerre_Channel_Pro.ex5
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
color=14381203
</graph>

<graph>
name=Lower Band
draw=1
style=2
width=1
color=14381203
</graph>

<graph>
name=Laguerre
draw=1
style=0
width=1
color=3937500
</graph>
<inputs>
=
InpGamma=0.5
InpSourcePrice=1
=
InpAtrPeriod=13
InpMultiplier=2.0
InpAtrSource=0
</inputs>
</indicator>
</window>

<window>
height=30.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Ehlers\2_Oscillators\Laguerre_RSI_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=1
scale_fix_min_val=0.000000
scale_fix_max=1
scale_fix_max_val=100.000000
expertmode=4
fixed_height=-1

<graph>
name=Laguerre RSI
draw=1
style=0
width=1
color=13422920
</graph>

<graph>
name=Signal
draw=1
style=0
width=1
color=8421616
</graph>

<level>
level=10.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=20.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=50.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=80.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=90.000000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
=
InpGamma=0.5
InpSourcePrice=1
=
InpDisplayMode=1
InpSignalPeriod=3
InpSignalMAType=1
</inputs>
</indicator>
</window>

<window>
height=30.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Ehlers\2_Oscillators\Laguerre_Stoch_Fast_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=1
scale_fix_min_val=0.000000
scale_fix_max=1
scale_fix_max_val=100.000000
expertmode=4
fixed_height=-1

<graph>
name=Fast %K
draw=1
style=0
width=1
color=11829830
</graph>

<graph>
name=Signal
draw=1
style=0
width=1
color=8421616
</graph>

<level>
level=10.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=20.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=50.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=80.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=90.000000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
=
InpGamma=0.5
InpSourcePrice=1
=
InpSignalPeriod=3
InpSignalMethod=0
</inputs>
</indicator>
</window>
</chart>
