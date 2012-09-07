; Used symbolism:
;  * variable name "t-carrier" means "the/this carrier in question", such as when passing it to a function, etc.
;


breed [people person]
people-own [
  income
  friendship-count
  talkativeness
  
  friends-with-operator
  friends-other
  
  monthly-bill
  potential-bill
  potential-operator
  operator-switch-cost
  willingness-to-switch
  
  ini-discount
  ini-discount-months
]

breed [carriers carrier]
carriers-own [
  subscribers-count
  subscribers-last
  
  temp-friends
]

undirected-link-breed [friends friend]
directed-link-breed [subscribers subscriber]

globals []



; ----------------------------------------------------------------------------------------------------
; ----- Setup phase ----------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


to setup
  clear-all
  
  create-social-network
  
  create-mobile-carriers

  layout-radial people friends (person 0)
  display
  ask people [
    ; Set label for people-nodes to be displayed
    ;set label __variable_here__
  ]
  
  reset-ticks
end


; ----- Create social network ---------------------------------------------------------------------------
to create-social-network
  set-default-shape people "circle"
  
  ; Create each person
  repeat number-of-people [
    create-people 1 [set color grey]
  ]
  
  ; Create the first friendship
  ask one-of people [
    create-friend-with one-of other people
  ]
  ; Create a friendship tree - each person will have at least 1 friendship
  ask people [
    create-friend-with one-of other people with [count friend-neighbors > 0]
  ]
  ; Create preset number of friendships above the necessary minimum created above
  repeat number-of-friendships [
    ask one-of people [
      create-friend-with one-of other people
    ]
  ]
end


; ----- Create mobile carriers ---------------------------------------------------------------------------
to create-mobile-carriers
  ; Create the carriers themselves
  create-carriers 1 [set color red ]
  create-carriers 1 [set color green]
  create-carriers 1 [set color blue]
  ask carriers [hide-turtle]
  
  ;;  Give each carrier one person and its friends as starting subscribers. (Owner and his friends.)
  ask carriers [
    let t-carrier self
    
    ask one-of people [
      create-subscriber-to t-carrier [hide-link]
      set color [color] of one-of out-subscriber-neighbors
      
      ask friend-neighbors [
        create-subscriber-to t-carrier [hide-link]
        set color [color] of one-of out-subscriber-neighbors
      ]
    ]
  ]
  
  color-friend-links-based-on-common-carrier
end



; ----------------------------------------------------------------------------------------------------
; ----- Go phase -------------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


; ----- Go --------------------------------------------------------------------------------------
to go
  ;output-print "\n------------------\n"
  
  if not any? people with [not any? out-subscriber-neighbors] [ stop ]
  
  spread-network
  
  tick
end


; ----- Spread network ---------------------------------------------------------------------------
to spread-network
  ; Spread network carriers
  ask people with [not any? out-subscriber-neighbors] [
    
    ;;  Find out about operators of their friends
    ask carriers [set temp-friends 0]  ; Reset the temporary counting variable of carriers
    let mobile-friends 0  ; Temp variable counting how many his friends have mobile phones
    ; Sum carriers of friends into temporary count variables
    ask friend-neighbors [
      ask out-subscriber-neighbors [
        set temp-friends temp-friends + 1
        set mobile-friends mobile-friends + 1
      ]
    ]
    ; Find out the highest number of friends with one carrier
    let most-used-count 0
    ask carriers [
      if most-used-count < temp-friends [set most-used-count temp-friends]
    ]
    
    ;;  Subscribe him to a carrier if he wants to.
    ifelse most-used-count > 0 [ ; If he has friends using mobile phones
      ; Weigh his options to join or not to join
      
      if random 100 < (mobile-friends * 10 / count friend-neighbors)  [
        ; Join the most sensible carrier (the one the most friends have, if the prices aren't that high of course)
        join-carrier one-of carriers with [temp-friends = most-used-count]
      ]
    ]
    [ ; If he does not have friends using mobile phones
      if random 100 < 1 [
        join-carrier one-of carriers  ; TODO he should join the carrier with the lowest price
      ]
    ]
  ]
  
  color-friend-links-based-on-common-carrier
end



; ----------------------------------------------------------------------------------------------------
; ----- Helper methods -------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


to color-friend-links-based-on-common-carrier
  ; Recolor friend links based on common carrier
  ask friends [
    let carrier1 [out-subscriber-neighbors] of end1
    if (count carrier1 > 0) and (carrier1 = [out-subscriber-neighbors] of end2) [
      set color [color] of one-of carrier1
    ]
  ]
end


to join-carrier [t-carrier]  ; person-turtle method
  create-subscriber-to t-carrier [hide-link]
  set color [color] of one-of out-subscriber-neighbors
end
  


to-report avg-friend-count
  let s 0
  ask people [
    set s s + count friend-neighbors
  ]
  report s / count people
end



; ----------------------------------------------------------------------------------------------------
; ----- Debug ----------------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


to debug-test
;  output-print "=========="
end










@#$#@#$#@
GRAPHICS-WINDOW
196
10
956
791
37
37
10.0
1
10
1
1
1
0
0
0
1
-37
37
-37
37
1
1
1
ticks
30.0

BUTTON
39
162
152
195
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
40
191
73
number-of-people
number-of-people
0
1000
705
1
1
NIL
HORIZONTAL

BUTTON
39
122
152
155
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
10
78
191
111
number-of-friendships
number-of-friendships
0
1000
554
1
1
NIL
HORIZONTAL

BUTTON
39
202
152
235
Go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
15
17
165
35
Setup variables
12
0.0
1

MONITOR
37
252
165
297
Carrier customers
count people with [count out-subscriber-neighbors > 0]
17
1
11

MONITOR
37
306
165
351
Carrier penetration (%)
100 * (count people with [count out-subscriber-neighbors > 0]) / number-of-people
1
1
11

BUTTON
34
758
177
791
Debug test button
debug-test
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
965
10
1381
313
Carrier penetration
NIL
%
0.0
10.0
0.0
10.0
true
false
"ask carriers [\n  set subscribers-count 0\n  set subscribers-last 0\n]" "ask carriers [\n  set subscribers-last subscribers-count\n  set subscribers-count count in-subscriber-neighbors\n]"
PENS
"default" 1.0 0 -16777216 true "" "ask carriers [\n  if subscribers-last > 0 [\n    plot-pen-up\n    plotxy (ticks - 1) (100 * subscribers-last / number-of-people)\n    plot-pen-down\n    set-plot-pen-color color\n    plotxy ticks (100 * subscribers-count / number-of-people)\n  ]\n]"

@#$#@#$#@
## WHAT IS IT?

## THINGS TO NOTICE

## EXTENDING THE MODEL

## NETLOGO FEATURES

## RELATED MODELS
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="spread1" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>net-stable?</exitCondition>
    <metric>count persons with [netmember?]</metric>
    <enumeratedValueSet variable="random-join?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-friendships">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="margin">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="spread2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>net-stable?</exitCondition>
    <metric>netmember-avg-friend-count</metric>
    <metric>all-persons-avg-friend-count</metric>
    <enumeratedValueSet variable="random-join?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-friendships">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="margin">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="spread3" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>net-stable?</exitCondition>
    <metric>netmember-avg-be-point</metric>
    <metric>all-persons-avg-be-point</metric>
    <enumeratedValueSet variable="random-join?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-friendships">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="margin">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random-join1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>net-stable?</exitCondition>
    <metric>count persons with [netmember?]</metric>
    <enumeratedValueSet variable="random-join?">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-of-friendships" first="50" step="2" last="500"/>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="margin">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random-join2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>net-stable?</exitCondition>
    <metric>count persons with [netmember?]</metric>
    <enumeratedValueSet variable="random-join?">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-of-friendships" first="50" step="2" last="500"/>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="margin">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random-join-584" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>net-stable?</exitCondition>
    <metric>all-persons-avg-friend-count</metric>
    <enumeratedValueSet variable="random-join?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-friendships">
      <value value="584"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="margin">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="bottleneck" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>bottleneck</go>
    <exitCondition>net-stable?</exitCondition>
    <metric>all-persons-avg-friend-count</metric>
    <metric>bottleneck-avg-friend-count</metric>
    <metric>all-persons-avg-be-point</metric>
    <metric>bottleneck-avg-be-point</metric>
    <metric>count persons with [bottleneck?]</metric>
    <metric>count persons with [not invited?]</metric>
    <steppedValueSet variable="number-of-friendships" first="50" step="10" last="500"/>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-join?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="margin">
      <value value="0.3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="max-profit1" repetitions="50" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50"/>
    <exitCondition>net-stable?</exitCondition>
    <metric>network-profit</metric>
    <metric>network-sale-revenue</metric>
    <metric>network-fee-revenue</metric>
    <metric>network-sponsor-cost</metric>
    <metric>network-manufacturing-cost</metric>
    <steppedValueSet variable="margin" first="0.01" step="0.01" last="0.6"/>
    <enumeratedValueSet variable="manufacturing-cost">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-friendships">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-join?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="max-profit2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50"/>
    <exitCondition>net-stable?</exitCondition>
    <metric>network-profit</metric>
    <metric>network-sale-revenue</metric>
    <metric>network-fee-revenue</metric>
    <metric>network-sponsor-cost</metric>
    <metric>network-manufacturing-cost</metric>
    <metric>count persons with [netmember?]</metric>
    <steppedValueSet variable="margin" first="0.05" step="0.01" last="0.9"/>
    <enumeratedValueSet variable="manufacturing-cost">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-friendships">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="monthly-fee">
      <value value="0"/>
      <value value="50"/>
      <value value="100"/>
      <value value="150"/>
      <value value="200"/>
      <value value="250"/>
      <value value="300"/>
      <value value="350"/>
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-join?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-persons">
      <value value="300"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
