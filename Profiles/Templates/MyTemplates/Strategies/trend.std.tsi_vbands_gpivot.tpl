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
color=11829830
</graph>

<graph>
name=VWAP (Segment)
draw=1
style=0
width=1
color=11829830
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
path=Indicators\Go Markets Pivot.ex5
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
UseTimeframe=1440
BarsToInclude=1
PivotType=1
UseCalcType=0
ShowMedians=1
s_Visual==== Lines and labels ===
ContinuousLines=0
ShowLabels=1
LabelBarOffset=8
LabelFontName=Arial
LabelFontSize=8
LabelText={LINE}
s_Colours==== Colours ===
PP_Colour=8421504
PP_Style=20
R1_Colour=8421504
R1_Style=10
R2_Colour=8421504
R2_Style=10
R3_Colour=8421504
R3_Style=10
S1_Colour=8421504
S1_Style=10
S2_Colour=8421504
S2_Style=10
S3_Colour=8421504
S3_Style=10
Median_Colour=8421504
Median_Style=2
s_Alerts==== Alerts ===
DoAlerts=0
AlertText={SYMBOL} {TF} {LINE} pivot hit {PRICE}
AlertSound=
WidenBy=0.0
WideMode=1
</inputs>
</indicator>
</window>

<window>
height=30.000000
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
</chart>
