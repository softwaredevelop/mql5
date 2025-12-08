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
mode=0
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
window_left=52
window_top=52
window_right=851
window_bottom=474
window_type=3
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
windows_total=4

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
path=Indicators\MyIndicators\Chart_HeikinAshi.ex5
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
name=HA Open;HA High;HA Low;HA Close
draw=17
style=0
width=1
arrow=251
color=15570276,1993170
</graph>

<graph>
name=OHLC
draw=0
style=0
width=1
arrow=251
color=
</graph>
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
color=8388608
</graph>

<graph>
name=FIR Filter
draw=1
style=0
width=1
color=9109504
</graph>
<inputs>
InpGamma=0.2
InpSourcePrice=1
InpShowFIR=false
</inputs>
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
color=255
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
color=3329434
</graph>

<graph>
name=FIR Filter
draw=1
style=0
width=1
color=9109504
</graph>
<inputs>
InpGamma=0.8
InpSourcePrice=1
InpShowFIR=false
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Murrey_Math_Line_X.ex5
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
InpPeriod=64
InpUpperTimeframe=16385
InpStepBack=0
InpLabelSide=0
=
InpFontFace=Verdana
InpFontSize=10
InpObjectPrefix=MML_Pro-
=
InpClr_m2_8=6908265
InpClr_m1_8=6908265
InpClr_0_8=36095
InpClr_1_8=2139610
InpClr_2_8=2237106
InpClr_3_8=5737262
InpClr_4_8=14772545
InpClr_5_8=5737262
InpClr_6_8=2237106
InpClr_7_8=2139610
InpClr_8_8=36095
InpClr_p1_8=6908265
InpClr_p2_8=6908265
=
InpWdth_m2_8=1
InpWdth_m1_8=1
InpWdth_0_8=1
InpWdth_1_8=1
InpWdth_2_8=1
InpWdth_3_8=1
InpWdth_4_8=1
InpWdth_5_8=1
InpWdth_6_8=1
InpWdth_7_8=1
InpWdth_8_8=1
InpWdth_p1_8=1
InpWdth_p2_8=1
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Session_Analysis_Pro.ex5
apply=0
show_data=0
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
name=M1 Pre VWAP
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=M1 Core VWAP
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=M1 Post VWAP
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=M1 Full VWAP
draw=1
style=0
width=1
color=8421504
</graph>

<graph>
name=
draw=1
style=0
width=1
color=8421504
</graph>

<graph>
name=M2 Pre VWAP
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=M2 Core VWAP
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=M2 Post VWAP
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=M2 Full VWAP
draw=1
style=0
width=1
color=8421504
</graph>

<graph>
name=
draw=1
style=0
width=1
color=8421504
</graph>

<graph>
name=M3 Pre VWAP
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=M3 Core VWAP
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=M3 Post VWAP
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=M3 Full VWAP
draw=1
style=0
width=1
color=8421504
</graph>

<graph>
name=
draw=1
style=0
width=1
color=8421504
</graph>
<inputs>
=
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=6
=
InpM1_Enable=true
=
InpM1_PreMarket_Enable=true
InpM1_PreMarket_Start=07:00
InpM1_PreMarket_End=10:00
InpM1_PreMarket_Color=6053069
InpM1_PreMarket_VWAP=true
InpM1_PreMarket_Mean=true
InpM1_PreMarket_LinReg=true
=
InpM1_Core_Enable=true
InpM1_Core_Start=10:00
InpM1_Core_End=18:30
InpM1_Core_Color=6053069
InpM1_Core_VWAP=true
InpM1_Core_Mean=true
InpM1_Core_LinReg=true
=
InpM1_PostMarket_Enable=true
InpM1_PostMarket_Start=18:30
InpM1_PostMarket_End=19:15
InpM1_PostMarket_Color=6053069
InpM1_PostMarket_VWAP=true
InpM1_PostMarket_Mean=true
InpM1_PostMarket_LinReg=true
=
InpM1_FullDay_Enable=false
InpM1_FullDay_Color=8421504
InpM1_FullDay_VWAP=false
InpM1_FullDay_Mean=false
InpM1_FullDay_LinReg=false
=
InpM2_Enable=true
=
InpM2_PreMarket_Enable=true
InpM2_PreMarket_Start=09:00
InpM2_PreMarket_End=10:00
InpM2_PreMarket_Color=5737262
InpM2_PreMarket_VWAP=true
InpM2_PreMarket_Mean=true
InpM2_PreMarket_LinReg=true
=
InpM2_Core_Enable=false
InpM2_Core_Start=10:00
InpM2_Core_End=18:30
InpM2_Core_Color=5737262
InpM2_Core_VWAP=true
InpM2_Core_Mean=true
InpM2_Core_LinReg=true
=
InpM2_PostMarket_Enable=true
InpM2_PostMarket_Start=18:30
InpM2_PostMarket_End=21:00
InpM2_PostMarket_Color=5737262
InpM2_PostMarket_VWAP=true
InpM2_PostMarket_Mean=true
InpM2_PostMarket_LinReg=true
=
InpM2_FullDay_Enable=false
InpM2_FullDay_Color=8421504
InpM2_FullDay_VWAP=false
InpM2_FullDay_Mean=false
InpM2_FullDay_LinReg=false
=
InpM3_Enable=true
=
InpM3_PreMarket_Enable=true
InpM3_PreMarket_Start=13:30
InpM3_PreMarket_End=16:30
InpM3_PreMarket_Color=13458026
InpM3_PreMarket_VWAP=true
InpM3_PreMarket_Mean=true
InpM3_PreMarket_LinReg=true
=
InpM3_Core_Enable=true
InpM3_Core_Start=16:30
InpM3_Core_End=23:00
InpM3_Core_Color=13458026
InpM3_Core_VWAP=true
InpM3_Core_Mean=true
InpM3_Core_LinReg=true
=
InpM3_PostMarket_Enable=true
InpM3_PostMarket_Start=23:00
InpM3_PostMarket_End=03:00
InpM3_PostMarket_Color=13458026
InpM3_PostMarket_VWAP=true
InpM3_PostMarket_Mean=true
InpM3_PostMarket_LinReg=true
=
InpM3_FullDay_Enable=false
InpM3_FullDay_Color=8421504
InpM3_FullDay_VWAP=false
InpM3_FullDay_Mean=false
InpM3_FullDay_LinReg=false
</inputs>
</indicator>

</window>

<window>
height=30.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Ehlers\5_Ehlers_Hybrids\MACD_Laguerre_Pro.ex5
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

<level>
level=0.000000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
=
InpGamma1=0.2
InpGamma2=0.8
=
InpSignalMAType=1
InpSignalPeriod=3
InpSignalGamma=0.5
=
InpSourcePrice=1
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
InpSignalMAType=0
</inputs>
</indicator>
</window>

<window>
height=30.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\ADX_Pro.ex5
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
name=ADX
draw=1
style=0
width=1
color=16748574
</graph>

<graph>
name=+DI
draw=1
style=0
width=1
color=2330219
</graph>

<graph>
name=-DI
draw=1
style=0
width=1
color=4678655
</graph>

<level>
level=25.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=40.000000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
InpPeriodADX=13
InpCandleSource=0
</inputs>
</indicator>
</window>
</chart>
