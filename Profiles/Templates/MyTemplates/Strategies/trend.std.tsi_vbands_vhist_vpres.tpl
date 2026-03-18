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
path=Indicators\MyIndicators\Quant\VScore_Bands_Pro.ex5
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
name=VWAP
draw=1
style=0
width=1
color=42495
</graph>

<graph>
name=
draw=1
style=0
width=1
color=42495
</graph>

<graph>
name=Bull Flow (+1.50)
draw=1
style=0
width=1
color=5275647
</graph>

<graph>
name=
draw=1
style=0
width=1
color=5275647
</graph>

<graph>
name=Bear Flow (-1.50)
draw=1
style=0
width=1
color=16436871
</graph>

<graph>
name=
draw=1
style=0
width=1
color=16436871
</graph>

<graph>
name=Bull Extr (+2.00)
draw=1
style=0
width=1
color=5275647
</graph>

<graph>
name=
draw=1
style=0
width=1
color=5275647
</graph>

<graph>
name=Bear Extr (-2.00)
draw=1
style=0
width=1
color=16436871
</graph>

<graph>
name=
draw=1
style=0
width=1
color=16436871
</graph>

<graph>
name=Bull Wall (+2.50)
draw=1
style=0
width=1
color=17919
</graph>

<graph>
name=
draw=1
style=0
width=1
color=17919
</graph>

<graph>
name=Bear Wall (-2.50)
draw=1
style=0
width=1
color=16760576
</graph>

<graph>
name=
draw=1
style=0
width=1
color=16760576
</graph>
<inputs>
<unnamed>=
InpPeriod=21
InpVWAPReset=0
InpVolumeType=0
<unnamed>=
InpLevelFlow=1.5
InpLevelExtreme=2.0
InpLevelWall=2.5
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\VWAP_Pro.ex5
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
name=VWAP
draw=1
style=0
width=1
color=17919
</graph>

<graph>
name=VWAP (Segment)
draw=1
style=0
width=1
color=17919
</graph>
<inputs>
<unnamed>=
InpResetPeriod=1
InpSessionTimezoneShift=0
<unnamed>=
InpCustomSessionStart=09:30
InpCustomSessionEnd=16:00
<unnamed>=
InpVolumeType=0
InpCandleSource=0
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\VWAP_History_Levels.ex5
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
name=
draw=0
style=0
width=1
color=
</graph>
<inputs>
<unnamed>=
InpShowDaily=true
InpDailyCount=4
InpDailyColor=9639167
<unnamed>=
InpShowWeekly=true
InpWeeklyCount=2
InpWeeklyColor=16748574
<unnamed>=
InpShowMonthly=true
InpMonthlyCount=1
InpMonthlyColor=13422920
</inputs>
</indicator>
</window>

<window>
height=25.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\TSI_Combo_Pro.ex5
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
name=Oscillator
draw=2
style=0
width=1
color=12632256
</graph>

<graph>
name=TSI
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
level=-50.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-37.500000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-25.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=25.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=37.500000
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
<inputs>
<unnamed>=
InpSlowPeriod=21
InpSlowMAType=1
InpFastPeriod=13
InpFastMAType=1
InpSourcePrice=1
<unnamed>=
InpSignalPeriod=13
InpSignalMAType=1
</inputs>
</indicator>
</window>

<window>
height=25.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Quant\VolumePressure_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=1
scale_fix_min_val=-1.100000
scale_fix_max=1
scale_fix_max_val=1.100000
expertmode=4
fixed_height=-1

<graph>
name=V_PRES
draw=11
style=0
width=2
color=255,65280
</graph>
<inputs>
InpSmoothPeriod=1
</inputs>
</indicator>
</window>
</chart>
