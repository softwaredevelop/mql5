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
mode=2
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
chartline_color=4294967295
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
path=Indicators\MyIndicators\Chart_HeikinAshi.ex5
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
name=HA Open;HA High;HA Low;HA Close
draw=17
style=0
width=1
color=15570276,1993170
</graph>

<graph>
name=OHLC
draw=0
style=0
width=1
color=
</graph>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Quant\Absorption_MTF_Pro.ex5
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
--- Timeframe Settings ---=
InpTimeframe=15
--- Indicator Settings ---=
InpATRPeriod=13
InpRVOLPeriod=21
InpHistoryBars=610
InpShowObjects=true
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Session_Analysis_Single_Pro.ex5
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
expertmode=0
fixed_height=-1

<graph>
name=Pre VWAP
draw=1
style=0
width=1
arrow=251
color=755384
</graph>

<graph>
name=Pre VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=755384
</graph>

<graph>
name=Core VWAP
draw=1
style=0
width=1
arrow=251
color=755384
</graph>

<graph>
name=Core VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=755384
</graph>

<graph>
name=Post VWAP
draw=1
style=0
width=1
arrow=251
color=755384
</graph>

<graph>
name=Post VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=755384
</graph>

<graph>
name=Full VWAP
draw=1
style=0
width=1
arrow=251
color=8421504
</graph>

<graph>
name=Full VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=8421504
</graph>
<inputs>
=
InpMarketName=TSE-summer
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=5
=
InpPre_Enable=true
InpPre_Start=02:00
InpPre_End=03:00
InpPre_Color=755384
InpPre_ShowVWAP=false
InpPre_ShowMean=true
InpPre_ShowLinReg=true
=
InpCore_Enable=true
InpCore_Start=03:00
InpCore_End=05:30
InpCore_Color=755384
InpCore_ShowVWAP=false
InpCore_ShowMean=true
InpCore_ShowLinReg=true
=
InpPost_Enable=true
InpPost_Start=06:30
InpPost_End=09:30
InpPost_Color=755384
InpPost_ShowVWAP=false
InpPost_ShowMean=true
InpPost_ShowLinReg=true
=
InpFull_Enable=false
InpFull_Color=8421504
InpFull_ShowVWAP=false
InpFull_ShowMean=false
InpFull_ShowLinReg=false
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Session_Analysis_Single_Pro.ex5
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
expertmode=0
fixed_height=-1

<graph>
name=Pre VWAP
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=Pre VWAP (Seg)
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=Core VWAP
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=Core VWAP (Seg)
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=Post VWAP
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=Post VWAP (Seg)
draw=1
style=0
width=1
color=6053069
</graph>

<graph>
name=Full VWAP
draw=1
style=0
width=1
color=8421504
</graph>

<graph>
name=Full VWAP (Seg)
draw=1
style=0
width=1
color=8421504
</graph>
<inputs>
=
InpMarketName=LSE
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=5
=
InpPre_Enable=true
InpPre_Start=07:00
InpPre_End=10:00
InpPre_Color=6053069
InpPre_ShowVWAP=false
InpPre_ShowMean=true
InpPre_ShowLinReg=true
=
InpCore_Enable=true
InpCore_Start=10:00
InpCore_End=18:30
InpCore_Color=6053069
InpCore_ShowVWAP=false
InpCore_ShowMean=true
InpCore_ShowLinReg=true
=
InpPost_Enable=true
InpPost_Start=18:30
InpPost_End=19:15
InpPost_Color=6053069
InpPost_ShowVWAP=false
InpPost_ShowMean=true
InpPost_ShowLinReg=true
=
InpFull_Enable=false
InpFull_Color=8421504
InpFull_ShowVWAP=false
InpFull_ShowMean=false
InpFull_ShowLinReg=false
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Session_Analysis_Single_Pro.ex5
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
expertmode=0
fixed_height=-1

<graph>
name=Pre VWAP
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=Pre VWAP (Seg)
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=Core VWAP
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=Core VWAP (Seg)
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=Post VWAP
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=Post VWAP (Seg)
draw=1
style=0
width=1
color=5737262
</graph>

<graph>
name=Full VWAP
draw=1
style=0
width=1
color=8421504
</graph>

<graph>
name=Full VWAP (Seg)
draw=1
style=0
width=1
color=8421504
</graph>
<inputs>
=
InpMarketName=XETRA
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=5
=
InpPre_Enable=true
InpPre_Start=09:00
InpPre_End=10:00
InpPre_Color=5737262
InpPre_ShowVWAP=false
InpPre_ShowMean=true
InpPre_ShowLinReg=true
=
InpCore_Enable=false
InpCore_Start=10:00
InpCore_End=18:30
InpCore_Color=5737262
InpCore_ShowVWAP=false
InpCore_ShowMean=true
InpCore_ShowLinReg=true
=
InpPost_Enable=true
InpPost_Start=18:30
InpPost_End=21:00
InpPost_Color=5737262
InpPost_ShowVWAP=false
InpPost_ShowMean=true
InpPost_ShowLinReg=true
=
InpFull_Enable=false
InpFull_Color=8421504
InpFull_ShowVWAP=false
InpFull_ShowMean=false
InpFull_ShowLinReg=false
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Session_Analysis_Single_Pro.ex5
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
expertmode=0
fixed_height=-1

<graph>
name=Pre VWAP
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=Pre VWAP (Seg)
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=Core VWAP
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=Core VWAP (Seg)
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=Post VWAP
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=Post VWAP (Seg)
draw=1
style=0
width=1
color=13458026
</graph>

<graph>
name=Full VWAP
draw=1
style=0
width=1
color=8421504
</graph>

<graph>
name=Full VWAP (Seg)
draw=1
style=0
width=1
color=8421504
</graph>
<inputs>
=
InpMarketName=NYSE
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=5
=
InpPre_Enable=true
InpPre_Start=13:30
InpPre_End=16:30
InpPre_Color=13458026
InpPre_ShowVWAP=false
InpPre_ShowMean=true
InpPre_ShowLinReg=true
=
InpCore_Enable=true
InpCore_Start=16:30
InpCore_End=23:00
InpCore_Color=13458026
InpCore_ShowVWAP=false
InpCore_ShowMean=true
InpCore_ShowLinReg=true
=
InpPost_Enable=true
InpPost_Start=23:00
InpPost_End=03:00
InpPost_Color=13458026
InpPost_ShowVWAP=false
InpPost_ShowMean=true
InpPost_ShowLinReg=true
=
InpFull_Enable=false
InpFull_Color=8421504
InpFull_ShowVWAP=false
InpFull_ShowMean=false
InpFull_ShowLinReg=false
</inputs>
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
InpTimeframe=16388
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
name=Laguerre Filter(γ=0.236)
draw=1
style=0
width=1
color=7346457
</graph>

<graph>
name=FIR Filter
draw=0
style=0
width=1
color=9109504
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Laguerre Settings ---=
InpGamma=0.236
InpSourcePrice=1
--- FIR Comparison Filter Settings ---=
InpShowFIR=false
--- Visual Settings - Laguerre Filter ---=
InpColorLaguerre=7346457
InpStyleLaguerre=0
InpWidthLaguerre=1
--- Visual Settings - FIR Filter ---=
InpColorFIR=9109504
InpStyleFIR=0
InpWidthFIR=1
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
name=Laguerre Filter(γ=0.500)
draw=1
style=0
width=1
color=3937500
</graph>

<graph>
name=FIR Filter
draw=0
style=0
width=1
color=9109504
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Laguerre Settings ---=
InpGamma=0.5
InpSourcePrice=1
--- FIR Comparison Filter Settings ---=
InpShowFIR=false
--- Visual Settings - Laguerre Filter ---=
InpColorLaguerre=3937500
InpStyleLaguerre=0
InpWidthLaguerre=1
--- Visual Settings - FIR Filter ---=
InpColorFIR=9109504
InpStyleFIR=0
InpWidthFIR=1
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
name=Laguerre Filter(γ=0.764)
draw=1
style=0
width=1
color=8421376
</graph>

<graph>
name=FIR Filter
draw=0
style=0
width=1
color=9109504
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Laguerre Settings ---=
InpGamma=0.764
InpSourcePrice=1
--- FIR Comparison Filter Settings ---=
InpShowFIR=false
--- Visual Settings - Laguerre Filter ---=
InpColorLaguerre=8421376
InpStyleLaguerre=0
InpWidthLaguerre=1
--- Visual Settings - FIR Filter ---=
InpColorFIR=9109504
InpStyleFIR=0
InpWidthFIR=1
</inputs>
</indicator>
</window>

<window>
height=25.000000
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
--- Timeframe Settings ---=
InpTimeframe=0
--- Laguerre RSI Settings ---=
InpGamma=0.236
InpSourcePrice=1
--- Signal Line Settings ---=
InpDisplayMode=1
InpSignalPeriod=3
InpSignalMAType=4
--- Indicator Levels (0-100 Range) ---=
InpLevelExtrHigh=90.0
InpLevelHigh=80.0
InpLevelMid=50.0
InpLevelLow=20.0
InpLevelExtrLow=10.0
InpLevelColor=12632256
InpLevelStyle=2
--- Visual Settings ---=
InpColorLRSI=13422920
InpStyleLRSI=0
InpWidthLRSI=1
InpColorSignal=8421616
InpStyleSignal=0
InpWidthSignal=1
</inputs>
</indicator>
</window>

<window>
height=25.000000
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
--- Timeframe Settings ---=
InpTimeframe=0
--- Laguerre RSI Settings ---=
InpGamma=0.5
InpSourcePrice=1
--- Signal Line Settings ---=
InpDisplayMode=1
InpSignalPeriod=3
InpSignalMAType=4
--- Indicator Levels (0-100 Range) ---=
InpLevelExtrHigh=90.0
InpLevelHigh=80.0
InpLevelMid=50.0
InpLevelLow=20.0
InpLevelExtrLow=10.0
InpLevelColor=12632256
InpLevelStyle=2
--- Visual Settings ---=
InpColorLRSI=13422920
InpStyleLRSI=0
InpWidthLRSI=1
InpColorSignal=8421616
InpStyleSignal=0
InpWidthSignal=1
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
--- Timeframe Settings ---=
InpTimeframe=0
--- Laguerre Settings ---=
InpGamma=0.236
InpSourcePrice=1
--- Stochastic Slowing & Signal Settings ---=
InpSlowingPeriod=3
InpSlowingMethod=0
InpSignalPeriod=3
InpSignalMethod=4
--- Indicator Levels (0-100 Range) ---=
InpLevelExtrHigh=90.0
InpLevelHigh=80.0
InpLevelMid=50.0
InpLevelLow=20.0
InpLevelExtrLow=10.0
InpLevelColor=12632256
InpLevelStyle=2
--- Visual Settings ---=
InpColorK=16748574
InpStyleK=0
InpWidthK=1
InpColorD=5275647
InpStyleD=0
InpWidthD=1
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
--- Timeframe Settings ---=
InpTimeframe=0
--- Laguerre Settings ---=
InpGamma=0.5
InpSourcePrice=1
--- Stochastic Slowing & Signal Settings ---=
InpSlowingPeriod=3
InpSlowingMethod=0
InpSignalPeriod=3
InpSignalMethod=4
--- Indicator Levels (0-100 Range) ---=
InpLevelExtrHigh=90.0
InpLevelHigh=80.0
InpLevelMid=50.0
InpLevelLow=20.0
InpLevelExtrLow=10.0
InpLevelColor=12632256
InpLevelStyle=2
--- Visual Settings ---=
InpColorK=16748574
InpStyleK=0
InpWidthK=1
InpColorD=5275647
InpStyleD=0
InpWidthD=1
</inputs>
</indicator>
</window>
</chart>
