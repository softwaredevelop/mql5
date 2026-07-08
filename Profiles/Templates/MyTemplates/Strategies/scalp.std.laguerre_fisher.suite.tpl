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
path=Indicators\MyIndicators\Authors\Ehlers\1_Smoothers\Laguerre_Filter_Pro.ex5
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
name=Laguerre Filter
draw=1
style=0
width=1
color=3937500
</graph>

<graph>
name=FIR Filter
draw=1
style=0
width=1
color=9109504
</graph>
<inputs>
InpGamma=0.5
InpSourcePrice=1
InpShowFIR=false
</inputs>
</indicator>
</window>

<window>
height=25.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Ehlers\5_Ehlers_Hybrids\LScore_Pro.ex5
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
name=L-Score
draw=11
style=0
width=2
color=8421504,16436871,16760576,5275647,17919
</graph>

<graph>
name=Signal
draw=1
style=0
width=1
color=2237106
</graph>

<level>
level=1.500000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-1.500000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=2.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-2.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=2.500000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-2.500000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
Laguerre Baseline Settings=
InpGamma=0.5
InpPrice=1
Volatility Settings=
InpPeriod=21
Signal Line Settings=
InpShowSignal=true
InpSignalPeriod=5
InpSignalType=3
Indicator Levels=
InpLevelFlowHigh=1.5
InpLevelFlowLow=-1.5
InpLevelClimaxHigh=2.0
InpLevelClimaxLow=-2.0
InpLevelExtremeHigh=2.5
InpLevelExtremeLow=-2.5
InpLevelColor=12632256
InpLevelStyle=2
</inputs>
</indicator>
</window>

<window>
height=25.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Quant\Velocity_Pro.ex5
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
name=Velocity
draw=11
style=0
width=2
color=8421504,16436871,16760576,5275647,17919
</graph>

<graph>
name=Speed (+)
draw=0
style=0
width=1
color=36095
</graph>

<graph>
name=Speed (-)
draw=0
style=0
width=1
color=36095
</graph>

<graph>
name=Signal
draw=1
style=0
width=1
color=2237106
</graph>

<level>
level=1.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-1.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=0.300000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-0.300000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
InpVelPeriod=3
InpATRPeriod=13
InpThresholdLow=0.3
InpThresholdHigh=1.0
InpShowSpeed=false
InpShowSignal=true
InpSignalPeriod=5
InpSignalType=3
</inputs>
</indicator>
</window>

<window>
height=25.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Ehlers\2_Oscillators\Laguerre_Stoch_Slow_Pro.ex5
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
name=Slow %K
draw=1
style=0
width=1
color=16748574
</graph>

<graph>
name=Signal %D
draw=1
style=0
width=1
color=5275647
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
Laguerre Settings=
InpGamma=0.5
InpSourcePrice=1
Stochastic Settings=
InpSlowingPeriod=3
InpSlowingMethod=3
InpSignalPeriod=3
InpSignalMethod=4
</inputs>
</indicator>
</window>

<window>
height=25.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Ehlers\2_Oscillators\Fisher_Transform_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=0
scale_fix_min_val=-5.059500
scale_fix_max=0
scale_fix_max_val=5.071500
expertmode=4
fixed_height=-1

<graph>
name=Fisher
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

<level>
level=1.500000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=0.750000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=0.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-0.750000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-1.500000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
Fisher Settings=
InpPeriod=8
InpAlpha=0.33
InpSource=0
Signal Line Settings=
InpSignalType=0
InpSignalPeriod=5
InpSignalMethod=0
</inputs>
</indicator>
</window>
</chart>
