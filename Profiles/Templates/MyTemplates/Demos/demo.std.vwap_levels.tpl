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
InpWeeklyCount=2
InpWeeklyColor=16748574
InpWeeklyStyle=0
InpWeeklyWidth=1
--- Monthly Historical Levels (PM-VWAP) ---=
InpShowMonthly=true
InpMonthlyCount=2
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
name=VWAP(PERIOD_SESSION)
draw=1
style=0
width=1
color=42495
</graph>

<graph>
name=VWAP (Segment)
draw=1
style=0
width=1
color=42495
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Period Settings ---=
InpResetPeriod=0
InpSessionTimezoneShift=0
InpCustomSessionStart=09:30
InpCustomSessionEnd=16:00
--- Calculation Settings ---=
InpVolumeType=0
InpCandleSource=0
--- Visual Settings ---=
InpColorVWAP=42495
InpStyleVWAP=0
InpWidthVWAP=1
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
</window>
</chart>
