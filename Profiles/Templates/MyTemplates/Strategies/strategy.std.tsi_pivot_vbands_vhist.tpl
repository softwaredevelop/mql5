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
path=Indicators\MyIndicators\PivotPoints_Pro.ex5
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
name=Pivot Point
draw=0
style=0
width=1
color=
</graph>

<graph>
name=R1
draw=0
style=0
width=1
color=
</graph>

<graph>
name=S1
draw=0
style=0
width=1
color=
</graph>

<graph>
name=R2
draw=0
style=0
width=1
color=
</graph>

<graph>
name=S2
draw=0
style=0
width=1
color=
</graph>

<graph>
name=R3
draw=0
style=0
width=1
color=
</graph>

<graph>
name=S3
draw=0
style=0
width=1
color=
</graph>

<graph>
name=S1-S2
draw=0
style=0
width=1
color=
</graph>

<graph>
name=PP-S1
draw=0
style=0
width=1
color=
</graph>

<graph>
name=PP-R1
draw=0
style=0
width=1
color=
</graph>

<graph>
name=R1-R2
draw=0
style=0
width=1
color=
</graph>

<graph>
name=R2-R3
draw=0
style=0
width=1
color=
</graph>

<graph>
name=S2-S3
draw=0
style=0
width=1
color=
</graph>
<inputs>
Timeframe Settings=
InpTimeframe=16408
Calculation Settings=
InpPivotType=0
InpSourceType=0
Visual Settings - Pivot Point=
InpColorPP=8421504
InpStylePP=0
InpWidthPP=2
Visual Settings - Resistance=
InpColorRes=8421504
InpStyleRes=0
InpWidthRes=1
Visual Settings - Support=
InpColorSup=8421504
InpStyleSup=0
InpWidthSup=1
Visual Settings - Medians=
InpShowMedians=true
InpColorMed=8421504
InpStyleMed=2
InpWidthMed=1
Labels=
InpShowLabels=false
InpLabelShift=10
InpFontSize=8
</inputs>
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
name=Bull Flow (+1.50σ)
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
name=Bear Flow (-1.50σ)
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
name=Bull Extr (+2.00σ)
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

<graph>
name=Bear Extr (-2.00σ)
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
name=Bull Wall (+2.50σ)
draw=1
style=0
width=1
color=7346457
</graph>

<graph>
name=
draw=1
style=0
width=1
color=7346457
</graph>

<graph>
name=Bear Wall (-2.50σ)
draw=1
style=0
width=1
color=139
</graph>

<graph>
name=
draw=1
style=0
width=1
color=139
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- V-Score Core Settings ---=
InpPeriod=21
InpVWAPReset=0
InpTzShift=0
InpCustomSessionStart=09:30
InpCustomSessionEnd=16:00
--- Calculation Settings ---=
InpVolumeType=0
InpCandleSource=0
--- V-Score Z-Levels (Standard Deviations) ---=
InpLevelFlow=1.5
InpLevelExtreme=2.0
InpLevelWall=2.5
--- Visual Settings - Centerline ---=
InpColorVWAP=42495
InpStyleVWAP=0
InpWidthVWAP=1
--- Visual Settings - Flow Bands (+/- 1.5σ) ---=
InpColorUpFlow=16436871
InpColorDnFlow=5275647
InpStyleFlow=0
InpWidthFlow=1
--- Visual Settings - Extreme Bands (+/- 2.0σ) ---=
InpColorUpExtr=16760576
InpColorDnExtr=17919
InpStyleExtr=0
InpWidthExtr=1
--- Visual Settings - Wall Bands (+/- 2.5σ) ---=
InpColorUpWall=7346457
InpColorDnWall=139
InpStyleWall=0
InpWidthWall=1
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
name=VWAP(PERIOD_WEEK)
draw=1
style=0
width=1
arrow=251
color=17919
</graph>

<graph>
name=VWAP (Segment)
draw=1
style=0
width=1
arrow=251
color=17919
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Period Settings ---=
InpResetPeriod=1
InpSessionTimezoneShift=0
InpCustomSessionStart=09:30
InpCustomSessionEnd=16:00
--- Calculation Settings ---=
InpVolumeType=0
InpCandleSource=0
--- Visual Settings ---=
InpColorVWAP=17919
InpStyleVWAP=0
InpWidthVWAP=1
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
--- Calculation & Source Settings ---=
InpVolumeType=0
InpCandleSource=0
InpTzShift=0
--- Daily Historical Levels (PD-VWAP) ---=
InpShowDaily=true
InpDailyCount=3
InpDailyColor=9639167
InpDailyStyle=0
InpDailyWidth=1
--- Weekly Historical Levels (PW-VWAP) ---=
InpShowWeekly=true
InpWeeklyCount=1
InpWeeklyColor=16748574
InpWeeklyStyle=0
InpWeeklyWidth=1
--- Monthly Historical Levels (PM-VWAP) ---=
InpShowMonthly=true
InpMonthlyCount=1
InpMonthlyColor=13422920
InpMonthlyStyle=0
InpMonthlyWidth=1
--- Custom Session Levels (e.g., Prior London Session) ---=
InpShowCustom=false
InpCustomStart=08:00
InpCustomEnd=16:30
InpCustomCount=2
InpCustomColor=55295
InpCustomStyle=0
InpCustomWidth=1
--- Visual & Label Settings ---=
InpShowLabels=true
InpLabelShift=8
InpFontSize=8
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
--- Timeframe Settings ---=
InpTimeframe=0
--- TSI Core Settings ---=
InpSlowPeriod=21
InpSlowMAType=1
InpFastPeriod=13
InpFastMAType=1
InpSourcePrice=1
--- Signal Line Settings ---=
InpSignalPeriod=13
InpSignalMAType=1
--- Indicator Levels ---=
InpLevelWallHigh=50.0
InpLevelExtrHigh=37.5
InpLevelOverbought=25.0
InpLevelOversold=-25.0
InpLevelExtrLow=-37.5
InpLevelWallLow=-50.0
InpLevelColor=12632256
InpLevelStyle=2
--- Visual Settings - TSI Line ---=
InpColorTSI=16748574
InpStyleTSI=0
InpWidthTSI=1
--- Visual Settings - Signal Line ---=
InpColorSignal=17919
InpStyleSignal=0
InpWidthSignal=1
--- Visual Settings - Histogram ---=
InpColorOsc=12632256
InpStyleOsc=0
InpWidthOsc=1
</inputs>
</indicator>
</chart>
