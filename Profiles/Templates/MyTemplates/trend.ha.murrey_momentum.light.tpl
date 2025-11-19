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
window_left=101
window_top=238
window_right=237
window_bottom=357
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
windows_total=3

<window>
height=100.000000
objects=26

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
=
InpFontFace=Verdana
InpFontSize=10
InpObjectPrefix=MML-
</inputs>
</indicator>
<object>
type=1
name=MML-line_0
hidden=1
color=6908265
background=1
selectable=0
value1=1.152039
</object>

<object>
type=101
name=MML-text_0
hidden=1
descr=[-2/8]P Extreme Overshoot
color=6908265
selectable=0
angle=0
date1=1762520400
value1=1.152039
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_1
hidden=1
color=6908265
background=1
selectable=0
value1=1.152802
</object>

<object>
type=101
name=MML-text_1
hidden=1
descr=[-1/8]P Overshoot
color=6908265
selectable=0
angle=0
date1=1762520400
value1=1.152802
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_2
hidden=1
color=36095
background=1
selectable=0
value1=1.153564
</object>

<object>
type=101
name=MML-text_2
hidden=1
descr=[0/8]P Ultimate Support
color=36095
selectable=0
angle=0
date1=1762520400
value1=1.153564
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_3
hidden=1
color=2139610
background=1
selectable=0
value1=1.154327
</object>

<object>
type=101
name=MML-text_3
hidden=1
descr=[1/8]P Weak, Stop & Reverse
color=2139610
selectable=0
angle=0
date1=1762520400
value1=1.154327
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_4
hidden=1
color=2237106
background=1
selectable=0
value1=1.155090
</object>

<object>
type=101
name=MML-text_4
hidden=1
descr=[2/8]P Pivot, Reverse
color=2237106
selectable=0
angle=0
date1=1762520400
value1=1.155090
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_5
hidden=1
color=5737262
background=1
selectable=0
value1=1.155853
</object>

<object>
type=101
name=MML-text_5
hidden=1
descr=[3/8]P Bottom of Trading Range
color=5737262
selectable=0
angle=0
date1=1762520400
value1=1.155853
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_6
hidden=1
color=14772545
background=1
selectable=0
value1=1.156616
</object>

<object>
type=101
name=MML-text_6
hidden=1
descr=[4/8]P Major S/R Pivot
color=14772545
selectable=0
angle=0
date1=1762520400
value1=1.156616
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_7
hidden=1
color=5737262
background=1
selectable=0
value1=1.157379
</object>

<object>
type=101
name=MML-text_7
hidden=1
descr=[5/8]P Top of Trading Range
color=5737262
selectable=0
angle=0
date1=1762520400
value1=1.157379
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_8
hidden=1
color=2237106
background=1
selectable=0
value1=1.158142
</object>

<object>
type=101
name=MML-text_8
hidden=1
descr=[6/8]P Pivot, Reverse
color=2237106
selectable=0
angle=0
date1=1762520400
value1=1.158142
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_9
hidden=1
color=2139610
background=1
selectable=0
value1=1.158905
</object>

<object>
type=101
name=MML-text_9
hidden=1
descr=[7/8]P Weak, Stop & Reverse
color=2139610
selectable=0
angle=0
date1=1762520400
value1=1.158905
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_10
hidden=1
color=36095
background=1
selectable=0
value1=1.159668
</object>

<object>
type=101
name=MML-text_10
hidden=1
descr=[8/8]P Ultimate Resistance
color=36095
selectable=0
angle=0
date1=1762520400
value1=1.159668
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_11
hidden=1
color=6908265
background=1
selectable=0
value1=1.160431
</object>

<object>
type=101
name=MML-text_11
hidden=1
descr=[+1/8]P Overshoot
color=6908265
selectable=0
angle=0
date1=1762520400
value1=1.160431
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

<object>
type=1
name=MML-line_12
hidden=1
color=6908265
background=1
selectable=0
value1=1.161194
</object>

<object>
type=101
name=MML-text_12
hidden=1
descr=[+2/8]P Extreme Overshoot
color=6908265
selectable=0
angle=0
date1=1762520400
value1=1.161194
fontsz=10
fontnm=Verdana
anchorpos=0
</object>

</window>

<window>
height=50.000000
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

<window>
height=50.000000
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
scale_fix_min=0
scale_fix_min_val=-92.109200
scale_fix_max=0
scale_fix_max_val=94.499200
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
