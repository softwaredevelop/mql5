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
color=755384
</graph>

<graph>
name=Pre VWAP (Seg)
draw=1
style=0
width=1
color=755384
</graph>

<graph>
name=Core VWAP
draw=1
style=0
width=1
color=755384
</graph>

<graph>
name=Core VWAP (Seg)
draw=1
style=0
width=1
color=755384
</graph>

<graph>
name=Post VWAP
draw=1
style=0
width=1
color=755384
</graph>

<graph>
name=Post VWAP (Seg)
draw=1
style=0
width=1
color=755384
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
InpMarketName=TSE-winter
InpFillBoxes=false
InpMaxHistoryDays=5
InpVolumeType=0
InpCandleSource=0
InpSourcePrice=5
=
InpPre_Enable=true
InpPre_Start=01:00
InpPre_End=02:00
InpPre_Color=755384
InpPre_ShowVWAP=true
InpPre_ShowMean=true
InpPre_ShowLinReg=true
=
InpCore_Enable=true
InpCore_Start=02:00
InpCore_End=04:30
InpCore_Color=755384
InpCore_ShowVWAP=true
InpCore_ShowMean=true
InpCore_ShowLinReg=true
=
InpPost_Enable=true
InpPost_Start=05:30
InpPost_End=08:30
InpPost_Color=755384
InpPost_ShowVWAP=true
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
InpPre_ShowVWAP=true
InpPre_ShowMean=true
InpPre_ShowLinReg=true
=
InpCore_Enable=true
InpCore_Start=10:00
InpCore_End=18:30
InpCore_Color=6053069
InpCore_ShowVWAP=true
InpCore_ShowMean=true
InpCore_ShowLinReg=true
=
InpPost_Enable=true
InpPost_Start=18:30
InpPost_End=19:15
InpPost_Color=6053069
InpPost_ShowVWAP=true
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
InpPre_ShowVWAP=true
InpPre_ShowMean=true
InpPre_ShowLinReg=true
=
InpCore_Enable=false
InpCore_Start=10:00
InpCore_End=18:30
InpCore_Color=5737262
InpCore_ShowVWAP=true
InpCore_ShowMean=true
InpCore_ShowLinReg=true
=
InpPost_Enable=true
InpPost_Start=18:30
InpPost_End=21:00
InpPost_Color=5737262
InpPost_ShowVWAP=true
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

</window>

<window>
height=30.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\StochRSI_Slow_Pro.ex5
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
color=16748574
</graph>

<graph>
name=%D
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
=
InpRSIPeriod=13
InpKPeriod=13
InpSlowingPeriod=3
InpDPeriod=3
=
InpSourcePrice=1
InpSlowingMAType=0
InpDMAType=0
</inputs>
</indicator>
</window>

<window>
height=30.000000
objects=0

<indicator>
name=Custom Indicator
path=Indicators\MyIndicators\SMI_Pro.ex5
apply=0
show_data=1
scale_inherit=0
scale_line=0
scale_line_percent=50
scale_line_value=0.000000
scale_fix_min=1
scale_fix_min_val=-100.000000
scale_fix_max=1
scale_fix_max_val=100.000000
expertmode=4
fixed_height=-1

<graph>
name=SMI
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
color=36095
</graph>

<level>
level=80.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=60.000000
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

<level>
level=0.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-40.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-60.000000
style=2
color=12632256
width=1
descr=
</level>

<level>
level=-80.000000
style=2
color=12632256
width=1
descr=
</level>
<inputs>
InpLengthK=13
InpLengthD=3
InpLengthEMA=3
InpCandleSource=0
</inputs>
</indicator>
</window>
</chart>
