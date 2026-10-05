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
Global Settings=
InpMarketName=TSE-summer
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=1
Pre-Market Session=
InpPre_Enable=true
InpPre_Start=02:00
InpPre_End=03:00
InpPre_Color=755384
InpPre_ShowVWAP=false
InpPre_ShowMean=true
InpPre_ShowLinReg=true
Core Trading Session=
InpCore_Enable=true
InpCore_Start=03:00
InpCore_End=05:30
InpCore_Color=755384
InpCore_ShowVWAP=false
InpCore_ShowMean=true
InpCore_ShowLinReg=true
Post-Market Session=
InpPost_Enable=true
InpPost_Start=06:30
InpPost_End=09:30
InpPost_Color=755384
InpPost_ShowVWAP=false
InpPost_ShowMean=true
InpPost_ShowLinReg=true
Full Day Analysis=
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
arrow=251
color=6053069
</graph>

<graph>
name=Pre VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=6053069
</graph>

<graph>
name=Core VWAP
draw=1
style=0
width=1
arrow=251
color=6053069
</graph>

<graph>
name=Core VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=6053069
</graph>

<graph>
name=Post VWAP
draw=1
style=0
width=1
arrow=251
color=6053069
</graph>

<graph>
name=Post VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=6053069
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
Global Settings=
InpMarketName=LSE
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=1
Pre-Market Session=
InpPre_Enable=true
InpPre_Start=07:00
InpPre_End=10:00
InpPre_Color=6053069
InpPre_ShowVWAP=false
InpPre_ShowMean=true
InpPre_ShowLinReg=true
Core Trading Session=
InpCore_Enable=true
InpCore_Start=10:00
InpCore_End=18:30
InpCore_Color=6053069
InpCore_ShowVWAP=false
InpCore_ShowMean=true
InpCore_ShowLinReg=true
Post-Market Session=
InpPost_Enable=true
InpPost_Start=18:30
InpPost_End=19:15
InpPost_Color=6053069
InpPost_ShowVWAP=false
InpPost_ShowMean=true
InpPost_ShowLinReg=true
Full Day Analysis=
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
arrow=251
color=5737262
</graph>

<graph>
name=Pre VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=5737262
</graph>

<graph>
name=Core VWAP
draw=1
style=0
width=1
arrow=251
color=5737262
</graph>

<graph>
name=Core VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=5737262
</graph>

<graph>
name=Post VWAP
draw=1
style=0
width=1
arrow=251
color=5737262
</graph>

<graph>
name=Post VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=5737262
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
Global Settings=
InpMarketName=XETRA
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=1
Pre-Market Session=
InpPre_Enable=true
InpPre_Start=09:00
InpPre_End=10:00
InpPre_Color=5737262
InpPre_ShowVWAP=false
InpPre_ShowMean=true
InpPre_ShowLinReg=true
Core Trading Session=
InpCore_Enable=false
InpCore_Start=10:00
InpCore_End=18:30
InpCore_Color=5737262
InpCore_ShowVWAP=false
InpCore_ShowMean=true
InpCore_ShowLinReg=true
Post-Market Session=
InpPost_Enable=true
InpPost_Start=18:30
InpPost_End=21:00
InpPost_Color=5737262
InpPost_ShowVWAP=false
InpPost_ShowMean=true
InpPost_ShowLinReg=true
Full Day Analysis=
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
arrow=251
color=13458026
</graph>

<graph>
name=Pre VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=13458026
</graph>

<graph>
name=Core VWAP
draw=1
style=0
width=1
arrow=251
color=13458026
</graph>

<graph>
name=Core VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=13458026
</graph>

<graph>
name=Post VWAP
draw=1
style=0
width=1
arrow=251
color=13458026
</graph>

<graph>
name=Post VWAP (Seg)
draw=1
style=0
width=1
arrow=251
color=13458026
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
Global Settings=
InpMarketName=NYSE
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=1
Pre-Market Session=
InpPre_Enable=true
InpPre_Start=13:30
InpPre_End=16:30
InpPre_Color=13458026
InpPre_ShowVWAP=false
InpPre_ShowMean=true
InpPre_ShowLinReg=true
Core Trading Session=
InpCore_Enable=true
InpCore_Start=16:30
InpCore_End=23:00
InpCore_Color=13458026
InpCore_ShowVWAP=false
InpCore_ShowMean=true
InpCore_ShowLinReg=true
Post-Market Session=
InpPost_Enable=true
InpPost_Start=23:00
InpPost_End=03:00
InpPost_Color=13458026
InpPost_ShowVWAP=false
InpPost_ShowMean=true
InpPost_ShowLinReg=true
Full Day Analysis=
InpFull_Enable=false
InpFull_Color=8421504
InpFull_ShowVWAP=false
InpFull_ShowMean=false
InpFull_ShowLinReg=false
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Kaufman\KAMA_Pro.ex5
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
name=KAMA(13,3,34)
draw=1
style=0
width=1
color=3937500
</graph>
<inputs>
Timeframe Settings=
InpTimeframe=0
KAMA Core Settings=
InpErPeriod=13
InpFastEmaPeriod=3
InpSlowEmaPeriod=34
InpSourcePrice=1
Visual Settings=
InpColorKAMA=3937500
InpStyleKAMA=0
InpWidthKAMA=1
</inputs>
</indicator>

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Ehlers\3_Adaptive_MAs\Laguerre_Adaptive_Filter_Pro.ex5
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
name=Laguerre Adaptive(ER,13,0.24-0.50)
draw=1
style=0
width=1
color=7346457
</graph>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Adaptive Baseline Settings ---=
InpAdaptiveMethod=0
InpAdaptivePeriod=13
InpGammaMin=0.236
InpGammaMax=0.5
InpSourcePrice=1
</inputs>
</indicator>
</window>

<window>
height=25.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\Authors\Ehlers\2_Oscillators\Laguerre_Adaptive_RSI_Pro.ex5
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
name=Laguerre Adaptive RSI
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
--- Adaptive Baseline Settings ---=
InpAdaptiveMethod=0
InpAdaptivePeriod=13
InpGammaMin=0.236
InpGammaMax=0.5
InpSourcePrice=1
--- Signal Line Settings ---=
InpShowSignal=true
InpSignalPeriod=3
InpSignalMAType=4
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
scale_fix_min_val=-1.259280
scale_fix_max=0
scale_fix_max_val=1.259280
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

<level>
level=-1.000000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
--- Timeframe Settings ---=
InpTimeframe=0
--- Velocity Kinematics Settings ---=
InpVelPeriod=3
InpATRPeriod=13
InpThresholdLow=0.3
InpThresholdHigh=1.0
InpSourcePrice=1
InpATRSource=0
--- Speed Envelope Settings ---=
InpShowSpeed=false
InpColorSpeed=36095
InpStyleSpeed=0
InpWidthSpeed=1
--- Signal Line Settings ---=
InpShowSignal=true
InpSignalPeriod=5
InpSignalType=3
InpColorSignal=2237106
--- Indicator Levels ---=
InpLevelClimaxPos=1.0
InpLevelFlowPos=0.3
InpLevelFlowNeg=-0.3
InpLevelClimaxNeg=-1.0
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
path=Indicators\MyIndicators\StochasticSlow_Pro.ex5
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
name=%K
draw=1
style=0
width=1
color=11186720
</graph>

<graph>
name=%D
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
--- Stochastic Settings ---=
InpKPeriod=13
InpSlowingPeriod=3
InpSlowingMAType=0
InpDPeriod=3
InpDMAType=0
InpCandleSource=0
</inputs>
</indicator>
</window>
</chart>
