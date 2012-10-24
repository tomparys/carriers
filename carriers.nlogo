; Used syntax:
;  * variable name "t-carrier" means "the/this carrier in question", such as when passing it to a function, etc.


breed [people person]
people-own [
  big    ; true/false, helper for two-circle social network
  income
  friends-count
  talkativeness
  
  monthly-bills-list
  
  ini-discount
  ini-discount-months
  
  ; Temp, counters and graphical representation
]

breed [carriers carrier]
carriers-own [
  subscribers-count
  
  price-in
  price-out
  ini-max-discount
  ini-current-discount
  ini-discount-giving-remaining
  
  ; Temp, counters and graphical representation
  subscribers-last
  ini-current-discount-last
  temp-friends
]

undirected-link-breed [friends friend]
directed-link-breed [subscribers subscriber]

globals [
  ; Variables, computed each turn
  total-mobile-subscribers
  carrier-switches-now
  carrier-switches-now-average
  
  ; Stable variables
  average-friends-count
  average-friends-count-big
  average-friends-count-nbig
  average-income
  
  ; Constants
  DISCOUNT-GIVING-DURATION
  DISCOUNT-DURATION
  MONTHLY-BILLS-COUNT-FOR-AVERAGE
  PROBABILITY-OF-CHECKING-BETTER-CARRIERS
  PROBABILITY-COEFFICIENT-FOR-CARRIER-SIGNUP-WITH-FRIENDS
  PROBABILITY-OF-CARRIER-SIGNUP-ALONE
  
  CARRIER-SWITCH-COST-COEFFICIENT
  
  ; Counters and graphical representation
  STATS-SAMPLING-INTERVAL
]



; ----------------------------------------------------------------------------------------------------
; ----- Setup phase ----------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


to setup
  clear-all
  set-constants
  
  ;; Create social network
  ifelse social-network-type = "Two-Circles" [
    create-social-network-two-circles
  ] [
    create-social-network-naive
  ]
  setup-people
  
  ;; Create first mobile carrier
  create-mobile-carrier 1

  reset-ticks
end


; ----- Set constants -----------------------------------------------------------------------------------
to set-constants
  set DISCOUNT-GIVING-DURATION 150                                         ; For how many ticks does Operator give out discounts
  set DISCOUNT-DURATION 30                                                 ; How many ticks does received discount last.
  set MONTHLY-BILLS-COUNT-FOR-AVERAGE 10                                   ; How many of recent bills are used for averaging.
  set PROBABILITY-OF-CHECKING-BETTER-CARRIERS 25                           ; per mille (All probability values are per mille.)
  set PROBABILITY-COEFFICIENT-FOR-CARRIER-SIGNUP-WITH-FRIENDS 100          ; per mille
  set PROBABILITY-OF-CARRIER-SIGNUP-ALONE 3                                ; per mille
  
  set CARRIER-SWITCH-COST-COEFFICIENT 0.5
  
  ; Counters and graphical representation
  set STATS-SAMPLING-INTERVAL 4                                            ; Used for displaying Carrier switches plot
end


; ----- Create social network - Two Circles ---------------------------------------------------------------------------
to create-social-network-two-circles
  ;; Constants
  let Bigs% 30
  let bigReach 30
  let allReach 18
  
  let nOfBigs Bigs% * nOfPeople / 100
  let nOfSmalls nOfPeople - nOfBigs
  
  ; Prepare the environment
  ask patches [set pcolor white]
  
  ;; Create people
  create-people nOfPeople
  ask people [
    set big false
    set shape "person"
    set color black
    set size 5
    setxy random-pxcor random-pycor
    while [any? other turtles-here] [fd 1]
  ]
  ask n-of nOfBigs people [
    set big true
    set size 7
  ]
  
  ;; Create friendships
  ask people with [big]  ; links big-big
    [create-friends-with other people with [big] in-radius bigReach]  ;;  [set color black]
  ask people  ; links big-small, s-b, s-s
    [create-friends-with other people with [not big] in-radius allReach] ;; [set color grey]

end


; ----- Create social network - Naive ---------------------------------------------------------------------------
to create-social-network-naive
  ;; Constants for creation of the network
  let number-of-friendships nOfPeople * 2
  
  set-default-shape people "circle"
  
  ; Create each person
  create-people nOfPeople [set color grey]
  
  ; Create the first friendship
  ask one-of people [create-friend-with one-of other people]
  
  ; Create a friendship tree - each person will have at least 1 friendship
  ask people [create-friend-with one-of other people with [count friend-neighbors > 0]]
  
  ; Create preset number of friendships above the necessary minimum created above
  repeat number-of-friendships [
    ask one-of people [create-friend-with one-of other people]
  ]
  
  ;;  Graphics and displays
  ask people [set size 5]
  ifelse layout-grouped [
    display-people-grouped-by-carrier
  ] [
    layout-radial people friends (person 0)
    display
  ]
end


; ----- Setup people (variables, etc.) ---------------------------------------------------------------------------
to setup-people
  ; Set variables
  ask people [set friends-count  count friend-neighbors]
  set average-friends-count  sum [friends-count] of people / count people
  set average-friends-count-big  sum [friends-count] of people with [big] / count people with [big]
  set average-friends-count-nbig  sum [friends-count] of people with [not big] / count people with [not big]

  ask people [
    set income  random-normal 100000 20000

    let talkativeness-centre (100 * friends-count / average-friends-count)
    set talkativeness  random-normal talkativeness-centre (min list (talkativeness-centre / 2) 50)
    set monthly-bills-list  []
  ]
  
  set average-income  sum [income] of people / count people
end


; ----- Create next mobile carrier (they are created one by one at any wanted moment) ---------------------------------------------------
to create-mobile-carrier [id]
  ;;  Create the carriers themselves and set their variables
  let created-carrier 0
  if id = 1 [
    create-carriers 1 [
      set color blue
      set price-in 131
      set price-out 131
      set ini-max-discount 0
      set created-carrier self
    ]
  ]
  if id = 2 [
    create-carriers 1 [
      set color red
      set price-in 109
      set price-out 159
      set ini-max-discount 15
      set created-carrier self
    ]
  ]
  if id = 3 [
    create-carriers 1 [
      set color green
      set price-in 80
      set price-out 180
      set ini-max-discount 30
      set created-carrier self
    ]
  ]
  
  ; Set common variables
  ask created-carrier [
    set ini-discount-giving-remaining  DISCOUNT-GIVING-DURATION
    set ini-current-discount  ini-max-discount
  ]
  
  ;;  Give each carrier one person and its friends as starting subscribers. (Owner and his friends.)
  ask created-carrier [
    ask one-of people [
      join-carrier created-carrier
      ask friend-neighbors [join-carrier created-carrier]
    ]
  ]
  
  ; Counters and graphical representation
  ask created-carrier [
    hide-turtle
    set subscribers-count count in-subscriber-neighbors
    set subscribers-last subscribers-count
    set ini-current-discount-last ini-current-discount
  ]
  color-friend-links-based-on-common-carrier
end



; ----------------------------------------------------------------------------------------------------
; ----- Go phase -------------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


; ----- Go --------------------------------------------------------------------------------------
to go
  ;output-print "\n------------------\n"
  
  ;;  Stopping is currently disabled
  ;if not any? people with [not any? out-subscriber-neighbors] [
  ;  if layout-grouped [repeat 200 [display-people-grouped-by-carrier]] ;; To sort into layout order the last connected subscribers
  ;  stop
  ;]
  
  customers-make-choices
  

  if ticks = 30 [create-mobile-carrier 2]
  if ticks = 80 [create-mobile-carrier 3]
  
  carriers-make-choices
  
  ; Counters and graphical representation
  color-friend-links-based-on-common-carrier
  if layout-grouped [display-people-grouped-by-carrier]
  
  if ticks mod STATS-SAMPLING-INTERVAL = 0 [
    set carrier-switches-now-average carrier-switches-now
    set carrier-switches-now 0
  ]
  
  tick
end


; ----- Carriers make choices ---------------------------------------------------------------------------
to carriers-make-choices
  ; Count subscribers
  ask carriers [
    set subscribers-last subscribers-count
    set subscribers-count count in-subscriber-neighbors
    
    if subscribers-count = 0 [die]
  ]
  
  ;;  Set discount levels for each carrier in the initial stage
  ask carriers [set ini-current-discount-last ini-current-discount]
;  ifelse total-mobile-subscribers < number-of-people [
    ; Compute global variables
;    set total-mobile-subscribers sum [subscribers-count] of carriers
;    let smallest-carrier-subscribers min [subscribers-count] of carriers
  
    ask carriers with [ini-discount-giving-remaining >= 0] [
      let need-of-discount  (ini-discount-giving-remaining / DISCOUNT-GIVING-DURATION) ; * ((smallest-carrier-subscribers / subscribers-count))

      set ini-current-discount  min (list ini-max-discount (ini-max-discount * need-of-discount * 2))
      
      set ini-discount-giving-remaining  ini-discount-giving-remaining - 1
    ]
;  ] [
;    ask carriers [set ini-current-discount 0]
;  ]
;  ]
end


; ----- Customers make choices ---------------------------------------------------------------------------
to customers-make-choices
  ; Spread network carriers
  ask people [
    let p-self self  ; save self to temp variable "person self"
    
    ;;  Find out about carriers of their friends
    ask carriers [set temp-friends 0]  ; Reset the temporary counting variable of carriers
    let mobile-friends 0  ; Temp variable counting how many his friends have mobile phones
    ; Sum carriers of friends into temporary count variables
    ask friend-neighbors [
      ask out-subscriber-neighbors [
        set temp-friends temp-friends + 1
        set mobile-friends mobile-friends + 1
      ]
    ]
    
    ; Compute monthly bill, if he is subscribed
    if has-carrier [
      let latest-bill 0
      ask get-carrier [
        ifelse mobile-friends > 0 [
          set latest-bill (temp-friends * price-in + (mobile-friends - temp-friends) * price-out) / mobile-friends
                             * [talkativeness] of p-self * (mobile-friends / [friends-count] of p-self)
                             * (get-discount-multiplier [ini-discount] of p-self)                              ; similar equation is a few rows below
        ] [
          ;; TODO - monthly bill if he has no friends              -- TODO
          set latest-bill 0
        ]
      ]  
      set monthly-bills-list lput latest-bill monthly-bills-list
      if length monthly-bills-list > MONTHLY-BILLS-COUNT-FOR-AVERAGE [
        set monthly-bills-list remove-item 0 monthly-bills-list
      ]
    ]
    
    ;;  Check to change or subscribe to a new carrier only sometimes
    
    ; Find out which carrier will give him the lowest monthly bill
    let lowest-potential-bill 999999999
    let lowest-potential-carrier 0
    
    if mobile-friends > 0 [
      ask carriers [
        ; Count potential bill
        let potential-bill (temp-friends * price-in + (mobile-friends - temp-friends) * price-out) / mobile-friends
                             * [talkativeness] of p-self * (mobile-friends / [friends-count] of p-self)
                             * (get-discount-multiplier ini-current-discount)                                  ; similar equation is a few rows above
      
        if lowest-potential-bill > potential-bill [
          set lowest-potential-bill potential-bill
          set lowest-potential-carrier self
        ]
      ]
    ]
      
    ifelse has-carrier [ ; Has a carrier already
      ifelse ini-discount-months > 0 [
        ;; If he has a discount, he can't leave the carrier, shorten the discount by a month
        set ini-discount-months ini-discount-months - 1
        if ini-discount-months = 0 [
          set ini-discount 0
        ]
      ] [ ;; He has no discount currently
        ; Check to change or subscribe to a new carrier only sometimes
        if random 1000 < PROBABILITY-OF-CHECKING-BETTER-CARRIERS [
          let average-monthly-bill get-average-monthly-bill
          
          if lowest-potential-bill < average-monthly-bill [  ; There is cheaper carrier for him
            ifelse get-carrier = lowest-potential-carrier [
              set ini-discount [ini-current-discount] of lowest-potential-carrier
            ] [
              ; Weigh the decision to change carrier
              let monthly-savings  average-monthly-bill - lowest-potential-bill
              let carrier-switch-cost  (friends-count / average-friends-count) * (income / average-income)
                                          * lowest-potential-bill * CARRIER-SWITCH-COST-COEFFICIENT
              
              if 4 * monthly-savings > carrier-switch-cost [
                change-carrier lowest-potential-carrier
              ]
            ]
          ]
        ]
      ]
    ]
    [ ; Does not have a carrier
      
      ;;  Subscribe to a carrier, if he wants to.
      ifelse mobile-friends > 0 [ ; If he has friends using mobile phones
        ; Weigh his options to join or not to join this month
        if random 1000 < (PROBABILITY-COEFFICIENT-FOR-CARRIER-SIGNUP-WITH-FRIENDS * mobile-friends / friends-count)  [
          ; Join the most sensible carrier
          join-carrier lowest-potential-carrier
        ]
      ]
      [ ; If he does not have friends using mobile phones
        if random 1000 < PROBABILITY-OF-CARRIER-SIGNUP-ALONE [
          join-carrier one-of carriers  ; TODO he should join the carrier with the lowest price
        ]
      ]
    ]
  ]
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

  set monthly-bills-list []
  set ini-discount [ini-current-discount] of t-carrier
  set ini-discount-months DISCOUNT-DURATION
  
  set color [color] of one-of out-subscriber-neighbors
end

to change-carrier [t-carrier]  ; Person method
  ask my-out-subscribers [die] ; Unsubscribe from the old carrier
  join-carrier t-carrier

  set carrier-switches-now carrier-switches-now + 1
end
  

to-report get-avg-friend-count
  let s 0
  ask people [
    set s s + count friend-neighbors
  ]
  report s / count people
end


to-report get-discount-multiplier [discount]
  report (100 - discount) / 100
end


to display-people-grouped-by-carrier
    layout-spring people (friends with [color != grey]) 1 1 1
    display
end


to-report has-carrier  ; Person method
  report count out-subscriber-neighbors > 0
end


to-report get-carrier  ; Person method
  report one-of out-subscriber-neighbors
end

to-report get-average-monthly-bill  ; Person method
  report (sum monthly-bills-list) / (length monthly-bills-list)
end



; ----------------------------------------------------------------------------------------------------
; ----- Debug ----------------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


to debug-test
  ;output-print "=========="

  ask one-of carriers with [color = green] [
    set price-in 85
    set price-out 155
  ]
end







@#$#@#$#@
GRAPHICS-WINDOW
196
10
799
634
157
157
1.883
1
1
1
1
1
0
1
1
1
-157
157
-157
157
1
1
1
ticks
30.0

BUTTON
38
76
151
109
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
7
216
188
249
nOfPeople
nOfPeople
500
1500
1000
10
1
NIL
HORIZONTAL

BUTTON
38
36
151
69
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

BUTTON
38
116
151
149
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
811
478
939
523
Carrier customers
;count people with [count out-subscriber-neighbors > 0]\ntotal-mobile-subscribers
17
1
11

MONITOR
948
479
1076
524
Carrier penetration (%)
100 * total-mobile-subscribers / nOfPeople
1
1
11

BUTTON
931
761
1074
794
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
810
10
1077
183
Carrier penetration
NIL
%
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "ask carriers [\n  plot-pen-up\n  plotxy (ticks - 1) (100 * subscribers-last / nOfPeople)\n  plot-pen-down\n  set-plot-pen-color color\n  plotxy ticks (100 * subscribers-count / nOfPeople)\n]"

PLOT
811
190
1077
310
Carriers' current discounts
NIL
%
0.0
10.0
0.0
40.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "ask carriers [\n  plot-pen-up\n  plotxy (ticks - 1) (ini-current-discount-last)\n  plot-pen-down\n  set-plot-pen-color color\n  plotxy ticks (ini-current-discount)\n]"

BUTTON
12
758
191
791
Group people by carrier
display-people-grouped-by-carrier
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
25
718
174
751
layout-grouped
layout-grouped
1
1
-1000

PLOT
811
318
1077
471
Carrier switches
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot carrier-switches-now-average"

CHOOSER
24
164
171
209
social-network-type
social-network-type
"Two-Circles" "Naive"
0

MONITOR
200
695
304
740
avg friends big
precision average-friends-count-big 3
17
1
11

MONITOR
201
746
303
791
avg friends nbig
precision average-friends-count-nbig 3
17
1
11

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
