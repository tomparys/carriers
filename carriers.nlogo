; Used syntax:
;  * Variable names of style "tCarrier" means "the/this/temp carrier in question", such as when passing it to a function, etc.
;        - similarly: l - list, n - number, p - person/probability
;  * Abbreviations: probability (prob), coefficient (coef), average (avg)

; Notes:
;   * Probabilities are usually given per mille (X in a 1000 chance)
;   * Prices are approximately measured in cents of CZK (halire)


globals [
  ; Variables, computed each turn
  totalMobileSubscribers
  carrierSwitchesNow
  carrierSwitchesNowAvg    ; average over the last x turns, used for better plotting
  
  ; Stable variables
  avgFriendsCount
  avgFriendsCount-big
  avgFriendsCount-nBig
  avgIncome
  
  ; Carrier settings for this run
  CARRIER_BLUE_PRICE_IN
  CARRIER_BLUE_PRICE_OUT
  CARRIER_BLUE_PRICE_IN_2
  CARRIER_BLUE_PRICE_OUT_2
  CARRIER_RED_ENTRANCE_TICK
  CARRIER_RED_PRICE_IN
  CARRIER_RED_PRICE_OUT
  CARRIER_RED_MAX_DISCOUNT
  CARRIER_GREEN_ENTRANCE_TICK
  CARRIER_GREEN_PRICE_IN
  CARRIER_GREEN_PRICE_OUT
  CARRIER_GREEN_MAX_DISCOUNT
  
  ; Essential constants
  COST_1MIN
  ACCESS_CHARGE
  INCOME_DISCOUNT_RATE
  
  ; Constants
  PRICE_RESPONSE_WAIT_TIME
  DISCOUNT_GIVING_DURATION
  DISCOUNT_DURATION
  MONTHLY_BILLS_COUNT-FOR_AVG

  ; Carrier signup and switching
  PROB_CUSTOMERS_CHECK_POSSIBILITIES
  COMP_PROB_CARRIER_SWITCH
  COMP_PROB_COEF_CARRIER_SIGNUP_WITH_FRIENDS
  CARRIER_SWITCH_COST_COEF
  
  ; Counters and graphical representation
  STATS_SAMPLING_INTERVAL
  ;DISCOUNTING_CURRENT_EXPONENT - commented out
  
  ; BehaviorSpace
  BEHAVIORAL_SPACE_EXPERIMENT  ; true/false
  equilibriumReachedAt
  equilibriumNearlyReachedAt
  carrierSwitchesLongterm
]


breed [people person]
people-own [
  big    ; true/false, helper for two-circle social network
  income
  friendsCount
  talkativeness
  
  lMonthlyBills  ; list of monthly bills
  
  iniDiscount
  iniDiscountMonths
]


breed [carriers carrier]
carriers-own [
  curRevenue              ; current monthly revenue (money paid by customers, costs are not yet deducted)
  curIncome               ; current monthly income
  accIncome               ; accumulated income - sum of past earnings
  accIncomeDiscounted     ; accumulated time-discounted income
  minsSupplied            ; how many minutes of calling the carrier supplied to its customers
  accessChargeBalance     ; how many minutes of access charge will carrier pay (or will be payed if < 0) at the end of the month
  
  priceIn
  priceOut
  iniMaxDiscount
  iniCurrentDiscount
  iniDiscountGivingRemaining
  
  ; Temp, counters and graphical representation
  curIncome-last
  accIncome-last
  accIncomeDiscounted-last
  subscribersCount
  subscribersCount-last
  iniCurrentDiscount-last
  tFriends     ; temporary count of friends
]


undirected-link-breed [friends friend]
directed-link-breed [subscribers subscriber]




; ----------------------------------------------------------------------------------------------------
; ----- Setup phase ----------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


; ----- Setup --------------------------------------------------------------------------------------
to setup [as_behavioral_space_experiment]
  clear-environment

  set BEHAVIORAL_SPACE_EXPERIMENT  as_behavioral_space_experiment
  set-constants

  ; BehavioralSpace setup
  set carrierSwitchesLongterm  []
  if BEHAVIORAL_SPACE_EXPERIMENT [ set stop_after_equilibrium? true ]
  
  ;; Create social network
  ifelse socialNetworkType = "Two-Circles"
    [create-social-network-two-circles]
    [create-social-network-randomized]
  setup-people
  
  ;; Create initial mobile carrier(s)
  handle-creation-of-mobile-carriers -1

  reset-ticks
end


; ----- Clear things after the last run ----------------------------------------------------------------
to clear-environment
  clear-all-plots
  clear-drawing
  clear-links
  clear-output
  clear-patches
  clear-ticks
  clear-turtles
  
  ;; Clear global variables
  set totalMobileSubscribers  0
  set carrierSwitchesNow  0
  set carrierSwitchesNowAvg  0
  set equilibriumReachedAt  0
  set equilibriumNearlyReachedAt  0
end


; ----- Set constants -----------------------------------------------------------------------------------
to set-constants
  ; Carrier settings for this run
  ifelse BEHAVIORAL_SPACE_EXPERIMENT [
    ; Behavioral space experiment
    set CARRIER_GREEN_ENTRANCE_TICK  -2  ; -1 is the setup round, les than that means never

    if CARRIER_BLUE_PRICE_IN_2 = -1 [ set CARRIER_BLUE_PRICE_IN_2  CARRIER_BLUE_PRICE_IN ]
    if CARRIER_BLUE_PRICE_OUT_2 = -1 [ set CARRIER_BLUE_PRICE_OUT_2  CARRIER_BLUE_PRICE_OUT ]
    if CARRIER_RED_PRICE_IN = -1 [ set CARRIER_RED_PRICE_IN  CARRIER_BLUE_PRICE_IN ]
    if CARRIER_RED_PRICE_OUT = -1 [ set CARRIER_RED_PRICE_OUT  CARRIER_BLUE_PRICE_OUT ]
  ] [
    ; Individual run
    set CARRIER_BLUE_PRICE_IN   100
    set CARRIER_BLUE_PRICE_OUT  450
    set CARRIER_BLUE_PRICE_IN_2   100
    set CARRIER_BLUE_PRICE_OUT_2  450
  
    set CARRIER_RED_ENTRANCE_TICK  70
    set CARRIER_RED_MAX_DISCOUNT  30
    set CARRIER_RED_PRICE_IN   300
    set CARRIER_RED_PRICE_OUT  250
    
    set CARRIER_GREEN_ENTRANCE_TICK  -140
    set CARRIER_GREEN_MAX_DISCOUNT  25
    set CARRIER_GREEN_PRICE_IN   160
    set CARRIER_GREEN_PRICE_OUT  200
  ]
  
  ; Essential constants
  set COST_1MIN             100        ; cost of 1 minute of calling for the operator
  set ACCESS_CHARGE         150        ; price paid to other carrier for connecting a call to his network per minute
  set INCOME_DISCOUNT_RATE  0.02       ; discount factor for accumulated earnings over time
  
  ; Other
  set PRICE_RESPONSE_WAIT_TIME  20                          ; How long do old carriers wait to do a price adjustment after new one enters the market
  set DISCOUNT_GIVING_DURATION  150                         ; For how many ticks does Operator give out discounts
  set DISCOUNT_DURATION  60                                 ; How many ticks does received discount last.
  set MONTHLY_BILLS_COUNT-FOR_AVG  10                       ; How many of recent bills are used for averaging.

  ; Carrier spreading and switching
  set PROB_CUSTOMERS_CHECK_POSSIBILITIES  100               ; Probability that person checks possibilities of other carriers or to enter the market
  set COMP_PROB_CARRIER_SWITCH  250                         ; Compound (with the above) prob. that he switches carrier if he is so inclined
  set COMP_PROB_COEF_CARRIER_SIGNUP_WITH_FRIENDS  1000      ; Compound probability coeficient for computation of probability of new signups
  set CARRIER_SWITCH_COST_COEF  10                          ; Roughly a price (i.e. in czech cents)
  
  ; Counters and graphical representation
  set STATS_SAMPLING_INTERVAL  4                            ; Used for displaying Carrier switches plot
  ;set DISCOUNTING_CURRENT_EXPONENT 1 - currently unused
end


; ----- Create social network - Two Circles ---------------------------------------------------------------------------
to create-social-network-two-circles
  ;; Constants
  let Bigs% 30
  let bigReach 50
  let allReach 25
  
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

  ;; Handle people with 0 friends (which is very rare)
  ask people with [count friend-neighbors = 0] [
    create-friends-with  min-n-of (1 + random 2) other people [distance myself]
  ]
end


; ----- Create social network - Randomized ---------------------------------------------------------------------------
to create-social-network-randomized
  ;; Constants for creation of the network
  let nFriendships nOfPeople * 2
  
  set-default-shape people "circle"
  
  ; Create each person
  create-people nOfPeople [
    set color white
    set big false
  ]
  
  ; Create the first friendship
  ask one-of people [create-friend-with one-of other people]
  
  ; Create a friendship tree - each person will have at least 1 friendship
  ask people [create-friend-with one-of other people with [count friend-neighbors > 0]]
  
  ; Create preset number of friendships above the necessary minimum created above
  repeat nFriendships [
    ask one-of people [create-friend-with one-of other people]
  ]
  
  ;;  Graphics and displays
  ask people [set size 5]
  ifelse randSN-layoutGrouped [
    display-layout-people-grouped-by-carrier
  ] [
    layout-radial people friends (person 0)
    display
  ]
end


; ----- Setup people (variables, etc.) ---------------------------------------------------------------------------
to setup-people
  ask people [set friendsCount  count friend-neighbors]
  set avgFriendsCount  sum [friendsCount] of people / count people
  
  set avgFriendsCount-nBig  sum [friendsCount] of people with [not big] / count people with [not big]
  ifelse socialNetworkType = "Two-Circles"
    [set avgFriendsCount-big  sum [friendsCount] of people with [big] / count people with [big]]
    [set avgFriendsCount-big  0]

  ask people [
    ;; Values set in czech cents and minutes. Data are roughly aligned with what statistics say about czech mobile phone users.
    set income  random-normal-min 50000 25000 5000

    let talkativenessCentre  (175 * friendsCount / avgFriendsCount)
    set talkativeness  random-normal-min talkativenessCentre (talkativenessCentre / 5) 20
    set lMonthlyBills  []
  ]
  
  set avgIncome  sum [income] of people / count people
end


; ----- Handle creation of mobile carriers at preset times and with preset constants ---------------------------------------------------
to handle-creation-of-mobile-carriers [nTicks]
  if nTicks = -1 [
    create-mobile-carrier blue CARRIER_BLUE_PRICE_IN CARRIER_BLUE_PRICE_OUT 0
  ]
  if nTicks = CARRIER_RED_ENTRANCE_TICK [
    create-mobile-carrier red CARRIER_RED_PRICE_IN CARRIER_RED_PRICE_OUT CARRIER_RED_MAX_DISCOUNT
  ]
  if nTicks = CARRIER_GREEN_ENTRANCE_TICK [
    create-mobile-carrier green CARRIER_GREEN_PRICE_IN CARRIER_GREEN_PRICE_OUT CARRIER_GREEN_MAX_DISCOUNT
  ]
  
  ; Handle the price change in response to the new Red by the old Blue carrier
  if nTicks = CARRIER_RED_ENTRANCE_TICK + PRICE_RESPONSE_WAIT_TIME [
    if CARRIER_BLUE_PRICE_IN_2 != 0 [
      ask carriers with [color = blue] [
        set priceIn  CARRIER_BLUE_PRICE_IN_2
        set priceOut  CARRIER_BLUE_PRICE_OUT_2
      ]
    ]
  ]
end

; ----- Helper method that initiates a mobile phone carrier ---------------------------------------------------
to create-mobile-carrier [tColor tPriceIn tPriceOut tIniMaxDiscount]
  create-carriers 1 [
    ; Set basic constants
    set color tColor
    set priceIn tPriceIn
    set priceOut tPriceOut
    set iniMaxDiscount tIniMaxDiscount
    
    ; Income variables
    set curRevenue  0
    set curIncome  0
    set curIncome-last  0
    set accIncome  0
    set accIncome-last  0
    set accIncomeDiscounted  0
    set accIncomeDiscounted-last  0
    set minsSupplied  0
    set accessChargeBalance  0 

    ; Helper variables
    set iniDiscountGivingRemaining  DISCOUNT_GIVING_DURATION
    set iniCurrentDiscount  iniMaxDiscount
    
    ; Give each carrier 3 people and 1/2 of their friends as starting subscribers. (Owner and his friends.)
    let carrierSelf self
    ask n-of 3 people [
      join-carrier carrierSelf
      ask n-of  precision (friendsCount / 2) 0  friend-neighbors  [join-carrier carrierSelf]
    ]

    ; Counters and graphical representation
    hide-turtle
    set subscribersCount count in-subscriber-neighbors
    set subscribersCount-last subscribersCount
    set iniCurrentDiscount-last iniCurrentDiscount
  ]
end




; ----------------------------------------------------------------------------------------------------
; ----- Go phase -------------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


; ----- Go --------------------------------------------------------------------------------------
to go
  ;; Check if equilibrium was reached
  if ticks >= 300 [
    let sumSwitches  sum carrierSwitchesLongterm
    
    if equilibriumNearlyReachedAt = 0 and sumSwitches < 5 [
      set equilibriumNearlyReachedAt  ticks
    ]
    if equilibriumReachedAt = 0 and sumSwitches = 0 [
      set equilibriumReachedAt  ticks
      if stop_after_equilibrium? [stop]
    ]
  ]
  
  
  customers-make-choices
  
  handle-creation-of-mobile-carriers ticks
  carriers-make-choices
  
  ;;  Counters and graphical representation
  color-friend-links-based-on-common-carrier
  if socialNetworkType = "Randomized" and randSN-layoutGrouped [display-layout-people-grouped-by-carrier]
  
  if ticks mod STATS_SAMPLING_INTERVAL = 0 [
    set carrierSwitchesNowAvg carrierSwitchesNow
    set carrierSwitchesNow 0
    
    set carrierSwitchesLongterm  lput carrierSwitchesNowAvg carrierSwitchesLongterm
    if length carrierSwitchesLongterm > 25 [
      set carrierSwitchesLongterm  remove-item 0 carrierSwitchesLongterm
    ]
  ] 
  if totalMobileSubscribers < nOfPeople [
    set totalMobileSubscribers  count people with [count out-subscriber-neighbors > 0]
  ]
  
  tick
end


; ----- Carriers make choices ---------------------------------------------------------------------------
to carriers-make-choices
  ;; Count subscribers
  ask carriers [
    set subscribersCount-last subscribersCount
    set subscribersCount count in-subscriber-neighbors
    
    if subscribersCount = 0 [die]
  ]
  
  ;;  Set discount levels for each carrier in the initial stage of their entrance to the market
  ask carriers [set iniCurrentDiscount-last iniCurrentDiscount]
  ask carriers with [iniDiscountGivingRemaining >= 0] [
    let needOfDiscount  (iniDiscountGivingRemaining / DISCOUNT_GIVING_DURATION)
    set iniCurrentDiscount  min (list iniMaxDiscount (iniMaxDiscount * needOfDiscount * 2))
      
    set iniDiscountGivingRemaining  iniDiscountGivingRemaining - 1
  ]
  
  ;; Accounting of revenue, costs and income
  ask carriers [
    set curIncome-last  curIncome
    set accIncome-last  accIncome
    set accIncomeDiscounted-last  accIncomeDiscounted
    
    let curCosts  minsSupplied * COST_1MIN + accessChargeBalance * ACCESS_CHARGE   ; costs can be negative, if he has negative accessChargeBalance!
    set curIncome  curRevenue - curCosts
    set accIncome  accIncome + curIncome
    set accIncomeDiscounted  (computeAccIncomeDiscounted accIncomeDiscounted curIncome)

    ; Reset variables that are filled in customers-make-choices between runs of this function carriers-make-choices
    set curRevenue  0
    set minsSupplied  0
    set accessChargeBalance  0
  ]
end


; ----- Customers make choices ---------------------------------------------------------------------------
to customers-make-choices
  ; Spread network carriers
  ask people [
    ;;  Find out about carriers of their friends
    ask carriers [set tFriends 0]  ; Reset the temporary counting variable of carriers
    let mobileFriends 0  ; Temp variable counting how many his friends have mobile phones
    ; Sum carriers of friends into temporary count variables
    ask friend-neighbors [
      ask out-subscriber-neighbors [
        set tFriends tFriends + 1
        set mobileFriends mobileFriends + 1
      ]
    ]
    let wantsTalkMins  talkativeness * (mobileFriends / friendsCount)
    
    ;;  Compute and pay a monthly bill, if he is subscribed
    if has-carrier [
      let latestBill 0

      ask get-carrier [
        ifelse mobileFriends > 0 [
          let avgPriceOf1Minute  (tFriends * priceIn + (mobileFriends - tFriends) * priceOut) / mobileFriends
                                        * (get-discount-multiplier [iniDiscount] of myself)                  ; similar equation is a few rows below
          set latestBill  avgPriceOf1Minute * wantsTalkMins
        ] [
          ;; TODO - monthly bill if he has no friends              -- TODO
          set latestBill 0
        ]
      ]
      
      ; Save (potential) monthly bill into list
      set lMonthlyBills lput latestBill lMonthlyBills
      if length lMonthlyBills > MONTHLY_BILLS_COUNT-FOR_AVG [
        set lMonthlyBills remove-item 0 lMonthlyBills
      ]
      
      ;;  Pay money for the services to the operator
      ;;    (BUT! not full bill, but only how much he can afford - he won't talk as long if he can't afford it)
      if latestBill > 0 [
        let actuallyTalkedMins wantsTalkMins
        let actuallyPaidBill latestBill
        
        if actuallyPaidBill > income [
          set actuallyPaidBill  income
          set actuallyTalkedMins  actuallyTalkedMins * actuallyPaidBill / latestBill  ; he talked only a portion of the time he wanted
        ]
        
        ask get-carrier [
          ; Carrier gets paid, and marks down how many minutes he supplied, and how many access charges he will have to pay
          set curRevenue  curRevenue + actuallyPaidBill
          set minsSupplied  minsSupplied + actuallyTalkedMins
          set accessChargeBalance  accessChargeBalance + actuallyTalkedMins * (mobileFriends - tFriends) / mobileFriends
          
          ask other carriers [
            ;; Access charges are deducted from AC balance of other carriers
            set accessChargeBalance  accessChargeBalance - actuallyTalkedMins * tFriends / mobileFriends
          ]
        ]
      ]
      
      ;;  Handle discounts 
      if iniDiscountMonths > 0 [
        set iniDiscountMonths  iniDiscountMonths - 1
        if iniDiscountMonths = 0 [
          set iniDiscount 0
        ]
      ]
    ]
    
    
    ;;  Check if it is worth it to subscribe to a new carrier
    if random 1000 < PROB_CUSTOMERS_CHECK_POSSIBILITIES [

      ; Find out which carrier will give him the lowest monthly bill
      let lowestPotentialBill 999999999
      let lowestPotentialCarrier 0
      
      if mobileFriends > 0 [
        ask carriers [
          ; Count potential bill
          let avgPriceOf1Minute  (tFriends * priceIn + (mobileFriends - tFriends) * priceOut) / mobileFriends
                                          * (get-discount-multiplier iniCurrentDiscount)                  ; similar equation is a few rows above
          let potentialBill  avgPriceOf1Minute * wantsTalkMins
          
          if lowestPotentialBill > potentialBill [
            set lowestPotentialBill  potentialBill
            set lowestPotentialCarrier  self
          ]
        ]
      ]
        
      ifelse has-carrier [ ; Has a carrier already
        if iniDiscountMonths = 0 [ ;; He has no discount currently
          ; Check to change or subscribe to a new carrier only sometimes
          if random 1000 < COMP_PROB_CARRIER_SWITCH  [
            let avgMonthlyBill  get-avgMonthlyBill
            
            if lowestPotentialBill < avgMonthlyBill [  ; There is cheaper carrier for him
              ifelse get-carrier = lowestPotentialCarrier [
                ; Resubscribe to his current carrier to receive a new discount
                set iniDiscount [iniCurrentDiscount] of lowestPotentialCarrier
                if iniDiscount > 0 [set iniDiscountMonths DISCOUNT_DURATION]
              ] [
                ; Weigh the decision to change carrier
                let monthlySavings  avgMonthlyBill - lowestPotentialBill
                let carrierSwitchCost  (friendsCount / avgFriendsCount) * (income / avgIncome) * CARRIER_SWITCH_COST_COEF
                
                if monthlySavings > carrierSwitchCost [
                  change-carrier lowestPotentialCarrier
                ]
              ]
            ]
          ]
        ]
      ]
      [ ; Does not have a carrier - subscribe if he has friends with mobiles
        if mobileFriends > 0 [
          ; Weigh his options to join or not to join this month
          if random 1000 < (COMP_PROB_COEF_CARRIER_SIGNUP_WITH_FRIENDS * mobileFriends / friendsCount)  [
            ; Join the most sensible carrier
            join-carrier lowestPotentialCarrier
          ]
        ]
      ]
    ]
  ]
end




; ----------------------------------------------------------------------------------------------------
; ----- Helper methods -------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


to-report computeAccIncomeDiscounted [tAccIncomeDiscounted tCurIncome]
  set tAccIncomeDiscounted  tAccIncomeDiscounted / (1 + INCOME_DISCOUNT_RATE)
  report tAccIncomeDiscounted + tCurIncome
  
  ;set tAccIncomeDiscounted  tAccIncomeDiscounted + tCurIncome / ((1 + INCOME_DISCOUNT_RATE) ^ DISCOUNTING_CURRENT_EXPONENT)
  ; Warning, DISCOUNTING_CURRENT_EXPONENT is being augmented in the Go function
    ; Discounted Income calculation
    ;if ticks mod 10 = 0 [ set DISCOUNTING_CURRENT_EXPONENT  DISCOUNTING_CURRENT_EXPONENT + 1 ]

  ;report tAccIncomeDiscounted
end

to join-carrier [t-carrier]  ; person-turtle method
  ask my-out-subscribers [die] ; Unsubscribe from the old carrier if by chance he has one
  create-subscriber-to t-carrier [hide-link]

  set lMonthlyBills []
  set iniDiscount [iniCurrentDiscount] of t-carrier
  if iniDiscount > 0 [set iniDiscountMonths DISCOUNT_DURATION]
  
  set color [color] of one-of out-subscriber-neighbors
end

to change-carrier [t-carrier]  ; Person method
  join-carrier t-carrier
  set carrierSwitchesNow carrierSwitchesNow + 1
end

to-report has-carrier  ; Person method
  report count out-subscriber-neighbors > 0
end

to-report get-carrier  ; Person method
  report one-of out-subscriber-neighbors
end


to-report get-discount-multiplier [discount]
  report (100 - discount) / 100
end

to-report get-avgMonthlyBill  ; Person method
  report (sum lMonthlyBills) / (length lMonthlyBills)
end

to-report random-normal-min [meanValue standardDeviation minimum]
  let r  random-normal meanValue standardDeviation
  ifelse r > minimum [report r]
    [report minimum]
end


to color-friend-links-based-on-common-carrier
  ; Recolor friend links based on common carrier
  ask friends [
    let carrier1 [out-subscriber-neighbors] of end1
    if (count carrier1 > 0) and (carrier1 = [out-subscriber-neighbors] of end2) [
      set color [color] of one-of carrier1
    ]
  ]
end

to display-layout-people-grouped-by-carrier
    layout-spring people (friends with [color != grey]) 1 1 1
    display
end


; ------- Helper methods for BehaviorSpace -----------------------------------------------------------

to-report reportCarrierData [cColor]
  let rep  (list (colorString cColor))
  
  ifelse any? carriers with [color = cColor] [
    set rep  lput true rep
    set rep  lput (item 0 ([subscribersCount] of carriers with [color = cColor])) rep
    set rep  lput round (item 0 ([curIncome] of carriers with [color = cColor])) rep
    set rep  lput round (item 0 ([accIncome] of carriers with [color = cColor])) rep
    set rep  lput round (item 0 ([accIncomeDiscounted] of carriers with [color = cColor])) rep
  ] [
    set rep  lput false rep
  ]
  
  report rep
end

to-report colorString [cColor]
  if cColor = blue [report "blue"]
  if cColor = red [report "red"]
  if cColor = green [report "green"]
  report "other"
end


; ----------------------------------------------------------------------------------------------------
; ----- Debug ----------------------------------------------------------------------------------------
; ----------------------------------------------------------------------------------------------------


to debug-test
  ; output-print "=========="
end
@#$#@#$#@
GRAPHICS-WINDOW
197
10
791
625
157
157
1.854
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
100
500
300
10
1
NIL
HORIZONTAL

BUTTON
38
36
151
69
Setup
setup false
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
331
698
459
743
Carrier customers
totalMobileSubscribers
17
1
11

MONITOR
331
749
459
794
Carrier penetration (%)
100 * totalMobileSubscribers / nOfPeople
1
1
11

BUTTON
35
680
178
713
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
"default" 1.0 0 -16777216 true "" "ask carriers [\n  plot-pen-up\n  plotxy (ticks - 1) (100 * subscribersCount-last / nOfPeople)\n  plot-pen-down\n  set-plot-pen-color color\n  plotxy ticks (100 * subscribersCount / nOfPeople)\n]"

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
"greens currently with discount" 1.0 0 -5509967 true "" "ifelse any? carriers with [color = green] [\n  plot count (([in-subscriber-neighbors] of (one-of carriers with [color = green]))\n                           with [iniDiscount > 0])\n                  * 100 / nOfPeople\n] [\n  plot 0\n]"
"reds currently with discount" 1.0 0 -1069655 true "" "ifelse any? carriers with [color = red] [\n  plot count (([in-subscriber-neighbors] of (one-of carriers with [color = red]))\n                           with [iniDiscount > 0])\n                  * 100 / nOfPeople\n] [\n  plot 0\n]"
"default" 1.0 0 -16777216 true "" "ask carriers [\n  plot-pen-up\n  plotxy (ticks - 1) (iniCurrentDiscount-last)\n  plot-pen-down\n  set-plot-pen-color color\n  plotxy ticks (iniCurrentDiscount)\n]"

BUTTON
21
757
200
790
Group people by carrier
display-layout-people-grouped-by-carrier
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
6
718
210
751
randSN-layoutGrouped
randSN-layoutGrouped
1
1
-1000

PLOT
811
318
1077
444
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
"default" 1.0 0 -16777216 true "" "plot carrierSwitchesNowAvg"

CHOOSER
24
164
171
209
socialNetworkType
socialNetworkType
"Two-Circles" "Randomized"
0

MONITOR
222
699
326
744
avg friends big
precision avgFriendsCount-big 3
17
1
11

MONITOR
223
750
325
795
avg friends nbig
precision avgFriendsCount-nBig 3
17
1
11

PLOT
811
452
1077
625
Current Income / 100
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
"default" 1.0 0 -16777216 true "" "ask carriers [\n  plot-pen-up\n  plotxy (ticks - 1) (curIncome-last / 100)\n  plot-pen-down\n  set-plot-pen-color color\n  plotxy ticks (curIncome / 100)\n]"

PLOT
811
632
1077
799
Accumulated Income / 100
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
"default" 1.0 0 -16777216 true "" "ask carriers [\n  plot-pen-up\n  plotxy (ticks - 1) (accIncome-last / 100)\n  plot-pen-down\n  set-plot-pen-color color\n  plotxy ticks (accIncome / 100)\n]"

MONITOR
8
575
176
620
NIL
equilibriumReachedAt
17
1
11

MONITOR
8
626
175
671
NIL
equilibriumNearlyReachedAt
17
1
11

PLOT
465
633
804
800
Accumulated Income Discounted / 100
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
"default" 1.0 0 -16777216 true "" "ask carriers [\n  plot-pen-up\n  plotxy (ticks - 1) (accIncomeDiscounted-last / 100)\n  plot-pen-down\n  set-plot-pen-color color\n  plotxy ticks (accIncomeDiscounted / 100)\n]"

MONITOR
17
442
184
487
Red price out
[priceOut] of one-of carriers with [color = red]
17
1
11

MONITOR
16
345
172
390
Red price in
[priceIn] of one-of carriers with [color = red]
17
1
11

BUTTON
18
300
146
333
RED PRICE IN +
ask carriers with [color = red] [\n  set priceIn  priceIn + 10\n]
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
17
401
157
434
RED PRICE OUT +
ask carriers with [color = red] [\n  set priceOut  priceOut + 10\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
7
255
192
288
stop_after_equilibrium?
stop_after_equilibrium?
1
1
-1000

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
NetLogo 5.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Monopoly-Blue-v1" repetitions="10" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <metric>equilibriumReachedAt</metric>
    <metric>equilibriumNearlyReachedAt</metric>
    <metric>nOfPeople</metric>
    <metric>reportCarrierData blue</metric>
    <metric>reportCarrierData red</metric>
    <metric>reportCarrierData green</metric>
    <enumeratedValueSet variable="random-seed">
      <value value="425758811"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN" first="100" step="25" last="400"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT" first="250" step="25" last="600"/>
    <enumeratedValueSet variable="CARRIER_BLUE_PRICE_IN_2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_BLUE_PRICE_OUT_2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_ENTRANCE_TICK">
      <value value="-2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_MAX_DISCOUNT">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_PRICE_IN">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_PRICE_OUT">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Nash-2car-noreaction-v1-sampling1" repetitions="5" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <metric>equilibriumReachedAt</metric>
    <metric>equilibriumNearlyReachedAt</metric>
    <metric>nOfPeople</metric>
    <metric>reportCarrierData blue</metric>
    <metric>reportCarrierData red</metric>
    <metric>reportCarrierData green</metric>
    <enumeratedValueSet variable="random-seed">
      <value value="-312590800"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN" first="100" step="100" last="300"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT" first="250" step="100" last="450"/>
    <enumeratedValueSet variable="CARRIER_BLUE_PRICE_IN_2">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_BLUE_PRICE_OUT_2">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_ENTRANCE_TICK">
      <value value="70"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_RED_MAX_DISCOUNT" first="0" step="15" last="30"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_IN" first="100" step="100" last="300"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_OUT" first="250" step="100" last="450"/>
  </experiment>
  <experiment name="Nash-2car-v3-sampling1" repetitions="5" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <metric>equilibriumReachedAt</metric>
    <metric>equilibriumNearlyReachedAt</metric>
    <metric>nOfPeople</metric>
    <metric>reportCarrierData blue</metric>
    <metric>reportCarrierData red</metric>
    <metric>reportCarrierData green</metric>
    <enumeratedValueSet variable="random-seed">
      <value value="-312590800"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN" first="100" step="100" last="300"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT" first="250" step="100" last="450"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN_2" first="100" step="100" last="300"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT_2" first="250" step="100" last="450"/>
    <enumeratedValueSet variable="CARRIER_RED_ENTRANCE_TICK">
      <value value="70"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_RED_MAX_DISCOUNT" first="0" step="15" last="30"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_IN" first="100" step="100" last="300"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_OUT" first="250" step="100" last="450"/>
  </experiment>
  <experiment name="Nash-2car-v3-sampling2" repetitions="5" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <metric>equilibriumReachedAt</metric>
    <metric>equilibriumNearlyReachedAt</metric>
    <metric>nOfPeople</metric>
    <metric>reportCarrierData blue</metric>
    <metric>reportCarrierData red</metric>
    <metric>reportCarrierData green</metric>
    <enumeratedValueSet variable="random-seed">
      <value value="1395684093"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN" first="100" step="50" last="300"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT" first="250" step="50" last="450"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN_2" first="100" step="50" last="300"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT_2" first="250" step="50" last="450"/>
    <enumeratedValueSet variable="CARRIER_RED_ENTRANCE_TICK">
      <value value="70"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_RED_MAX_DISCOUNT" first="0" step="15" last="30"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_IN" first="100" step="50" last="300"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_OUT" first="250" step="50" last="450"/>
  </experiment>
  <experiment name="Nash-2car-v3-sampling3" repetitions="5" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <metric>equilibriumReachedAt</metric>
    <metric>equilibriumNearlyReachedAt</metric>
    <metric>nOfPeople</metric>
    <metric>reportCarrierData blue</metric>
    <metric>reportCarrierData red</metric>
    <metric>reportCarrierData green</metric>
    <enumeratedValueSet variable="random-seed">
      <value value="-1119562889"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN" first="100" step="50" last="300"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT" first="250" step="50" last="450"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN_2" first="100" step="50" last="300"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT_2" first="250" step="50" last="450"/>
    <enumeratedValueSet variable="CARRIER_RED_ENTRANCE_TICK">
      <value value="70"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_RED_MAX_DISCOUNT" first="0" step="15" last="30"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_IN" first="100" step="50" last="300"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_OUT" first="250" step="50" last="450"/>
  </experiment>
  <experiment name="Cartel-v1-sampling1" repetitions="5" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <metric>equilibriumReachedAt</metric>
    <metric>equilibriumNearlyReachedAt</metric>
    <metric>nOfPeople</metric>
    <metric>reportCarrierData blue</metric>
    <metric>reportCarrierData red</metric>
    <metric>reportCarrierData green</metric>
    <enumeratedValueSet variable="random-seed">
      <value value="-312590800"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN" first="100" step="25" last="500"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT" first="250" step="25" last="650"/>
    <enumeratedValueSet variable="CARRIER_BLUE_PRICE_IN_2">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_BLUE_PRICE_OUT_2">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_ENTRANCE_TICK">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_MAX_DISCOUNT">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_PRICE_IN">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_PRICE_OUT">
      <value value="-1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="NewNash-2car-simultaneous-v1" repetitions="1" runMetricsEveryStep="false">
    <setup>setup true</setup>
    <go>go</go>
    <metric>equilibriumReachedAt</metric>
    <metric>equilibriumNearlyReachedAt</metric>
    <metric>nOfPeople</metric>
    <metric>reportCarrierData blue</metric>
    <metric>reportCarrierData red</metric>
    <metric>reportCarrierData green</metric>
    <enumeratedValueSet variable="random-seed">
      <value value="-312590800"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_IN" first="100" step="50" last="400"/>
    <steppedValueSet variable="CARRIER_BLUE_PRICE_OUT" first="250" step="50" last="550"/>
    <enumeratedValueSet variable="CARRIER_BLUE_PRICE_IN_2">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_BLUE_PRICE_OUT_2">
      <value value="-1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_ENTRANCE_TICK">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CARRIER_RED_MAX_DISCOUNT">
      <value value="0"/>
    </enumeratedValueSet>
    <steppedValueSet variable="CARRIER_RED_PRICE_IN" first="100" step="50" last="400"/>
    <steppedValueSet variable="CARRIER_RED_PRICE_OUT" first="250" step="50" last="550"/>
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
