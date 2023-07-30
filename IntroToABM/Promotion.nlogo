extensions [ nw ]
turtles-own [org-level org-weight competence bias discernment halo score ever-selected]
globals [N candidates selected-candidate max-org-competence abs-org-competence org-competence TraitVisualisation]
breed [employees employee]
breed [CEOs CEO]
breed [vacancies vacancy]
breed [externals external]



to SetupOrg
  nw:set-context turtles links
  clear-all
  create-heirarchy-part 1 nobody
  layout-organisation
  SetupEmployees
end

to layout-organisation
  set N count turtles

  (ifelse
    OrgLayout = "Spring Network"[
      repeat 30 [ layout-spring turtles links 1 1 1 ]
    ]
    OrgLayout = "Radial Network"[
      layout-radial turtles links one-of CEOs
    ]
    OrgLayout = "Grid"[
      let d  sqrt ( ( (world-width - 2) * (world-height - 2) ) / N )
      let row-col-max ((world-width - 1)/ d)
      let level-list (range 2 (OrgLevels + 1))
      let row 0
      let col 0

      foreach level-list
        [ this-level ->
          ask employees with [org-level = this-level][
            set xcor  (d  * (0.5 + col))  - ( world-width / 2 )
            set ycor  ( world-height / 2) - (d * (0.5 + row))
            set col col + 1
            if col > row-col-max[
              set col 0
              set row row + 1
            ]
          ]
        ]
    ])
end

to create-heirarchy-part [level manager]
  ifelse manager = nobody
    [create-CEOs 1 [
      set org-level level
      set org-weight 0
      set manager self]]
    [create-employees 1 [
      create-link-to manager
      set org-level level
      set org-weight 0
      set ever-selected false
      set manager self
      let reporting-chain nw:turtles-on-path-to one-of CEOs
      foreach reporting-chain[
        the-employee -> ask the-employee [add-to-org-weight self]
      ]
    ]
  ]
  if level < OrgLevels [
    set level  (level + 1)
    repeat TeamSize [create-heirarchy-part level manager]
  ]
end

to add-to-org-weight[an-employee]
  ask an-employee[
    set org-weight org-weight + 1
  ]
end

to assign-traits-to [an-employee]
  ask an-employee[
    set competence random-normal 50 10
    set bias random-normal 50 10
    set discernment random-normal 50 10
    set halo random-normal 50 10
  ]
end

to update-appearance-of [an-employee]
  ask an-employee[
    ifelse breed = externals
      [set hidden? true]
      [set hidden? false]
    ifelse ever-selected = true [
      (ifelse
        org-level = 2 [set shape "triangle"]
        org-level = 3 [set shape "square"]
        org-level = 4 [set shape "pentagon"]
        org-level = 5 [set shape "circle"]
      )
    ]
    [
      (ifelse
        org-level = 2 [set shape "triangle 2"]
        org-level = 3 [set shape "square 2"]
        org-level = 4 [set shape "star"]
        org-level = 5 [set shape "circle 2"]
      )

    ]
    set size (competence / 100)
    (ifelse
      TraitVisualisation = "Green"[
        set color scale-color green halo 30 70
      ]
      TraitVisualisation = "Rainbow"[
        let halo-strata floor ( halo / 10 )
        (ifelse
          halo-strata = 0 [set color red]
          halo-strata = 1 [set color orange]
          halo-strata = 2 [set color yellow]
          halo-strata = 3 [set color green]
          halo-strata = 4 [set color lime]
          halo-strata = 5 [set color cyan]
          halo-strata = 6 [set color sky]
          halo-strata = 7 [set color blue]
          halo-strata = 8 [set color violet]
          halo-strata = 9 [set color magenta]
        )
      ])

    if breed = CEOs[
      set color red
    ]
    if OrgLayout = "Grid"[
      ask my-links [ hide-link ]
      if breed = CEOs[
        set hidden? true
    ]]
  ]
end

to SetupEmployees
  ask externals [die]
  ask employees[
    assign-traits-to self
    update-appearance-of self
  ]
  ask CEOs[
    assign-traits-to self
    update-appearance-of self
  ]
  ask vacancies[
    set breed employees
    assign-traits-to self
    update-appearance-of self
  ]
  create-a-vacancy
  calculate-org-competence
  clear-all-plots
  reset-ticks
end

to create-a-vacancy
  ask one-of employees [
    set breed vacancies
    set color blue
    set shape "square"
  ]
end

to source-external-canditates-for [the-vacancy ]
  let external-x-patch -16
  create-externals TeamSize ^ 2[              ;; Create as many external candidates as we would have had in the internal senario
    assign-traits-to self
    update-appearance-of self
    move-to patch external-x-patch -16
    set external-x-patch external-x-patch + 1
  ]
  set candidates externals
end

to source-internal-canditates-for [the-vacancy recruiting-manager]
  set candidates employees with [org-level = ( ([org-level] of the-vacancy) + 1)] ;; Start with all employees on the level below the vacancy
  set candidates candidates with [ nw:distance-to recruiting-manager != false]    ;; Remove those who do not have a reporting line to the recruiting manager
  set candidates candidates with [ nw:distance-to recruiting-manager = 2]         ;; This might be redundant, but remove those who are further away than 2 links
end
                                                                                  ;;============================================================================;;
to select-candidate-by [recruiting-manager]                                       ;; This is where we can implment different recruitment strategies             ;;
  (ifelse
    RecruitmentStrategy = "Competence"[
      select-candidate-by-competence
    ]
    RecruitmentStrategy = "Random"[
      select-candidate-by-random
    ]
    RecruitmentStrategy = "Affinity"[
      select-candidate-by-affinity recruiting-manager
    ]
    RecruitmentStrategy = "Affinity or Competence"[
      select-candidate-by-affinity-or-competence recruiting-manager
    ]
    RecruitmentStrategy = "Discernment"[
      select-candidate-by-discernment recruiting-manager
    ]
    [
      select-candidate-by-random
      print "unknown strategy"
    ])

  ask selected-candidate[
    ;; Used to change apperance, could also be used for debugging
    set ever-selected true
  ]
end

to select-candidate-by-competence                                                 ;; This represents the best case situation, omniscient recruiting managers.
  set selected-candidate one-of candidates with-max [competence]
end

to select-candidate-by-random                                                     ;; This represents the worst case, chooseing randomly
  set selected-candidate one-of candidates
end

to select-candidate-by-affinity [recruiting-manager]                              ;; The recruiting manager selects the candidate most similar to them in regard to the halo-trait
  ask candidates[
    set score abs ( halo - [halo] of recruiting-manager )
  ]
  set selected-candidate one-of candidates with-min [score]
end

to select-candidate-by-affinity-or-competence [recruiting-manager]                ;; Dependingon on if the recruiting managers discernment trait is high or low,
  ifelse [discernment] of recruiting-manager > 50                                 ;; they either select the candidate most similar to them (regarding halo),
    [ set selected-candidate one-of candidates with-max [competence] ]            ;; or select the most competent candidate.
    [ ask candidates[
      set score abs ( halo - [halo] of recruiting-manager )
      ]
      set selected-candidate one-of candidates with-min [score] ]
end

to select-candidate-by-discernment [recruiting-manager]                           ;; Thew recruiting managers discernment trait decides how likely it is that
  ask candidates[                                                                 ;; they can discern between the competence trait and halo traits of the candidates.
    ;; Create a diff normally distrubuted 0 to 100 mean 50
    let diff ( (competence - halo) + 100 ) / 2
    ifelse diff < [discernment] of recruiting-manager
    [ set score competence ]
    [ set score halo ]
  ]
  set selected-candidate one-of candidates with-max [score]
end



to place-selected-candidate-in [the-vacancy recruiting-manager]
  let next-vacancy-direct-reports nobody
  let next-vacancy-manager nobody
  let next-vacancy-org-level 0
  let next-vacancy-org-weight 0
  let next-vacancy-x 0
  let next-vacancy-y 0
  let this-vacancy-direct-reports nobody
  let this-vacancy-org-level 0
  let this-vacancy-org-weight 0
  let this-vacancy-x 0
  let this-vacancy-y 0
  let is-internal-recruitment false
  let is-in-team-promotion false

  ask selected-candidate[
    if breed != externals[                                   ;; If the selected candidate is internal, we need to save the links, and coordinates
      set is-internal-recruitment true                       ;; in order to connect the next vacancy properly
    ]
    if one-of out-link-neighbors = the-vacancy[              ;; If the manager of the selected candidate, is where the vacancy was
      set is-in-team-promotion true                          ;; this means that the selected candidate will be the next recruiting manager.
    ]
  ]

  if is-internal-recruitment[
    ask selected-candidate[
      set next-vacancy-direct-reports in-link-neighbors
      ifelse is-in-team-promotion
        [set next-vacancy-manager selected-candidate]         ;; Internal promotion => The selected candidate creates a vacancy they will have to recruit for
        [set next-vacancy-manager one-of out-link-neighbors]
      set next-vacancy-org-level org-level
      set next-vacancy-org-weight org-weight
      set next-vacancy-x xcor
      set next-vacancy-y ycor
      ask my-out-links [die]
      ask my-in-links [die]
    ]
  ]

  ask the-vacancy[
    set this-vacancy-direct-reports in-link-neighbors
    set this-vacancy-x xcor
    set this-vacancy-y ycor
    set this-vacancy-org-level org-level
    set this-vacancy-org-weight org-weight
    ask my-out-links [die]
    ask my-in-links [die]
  ]

  ask selected-candidate[
    set breed employees
    set xcor this-vacancy-x
    set ycor this-vacancy-y
    set org-level this-vacancy-org-level
    set org-weight this-vacancy-org-weight
    create-link-to recruiting-manager
    if this-vacancy-direct-reports != nobody[
      ask this-vacancy-direct-reports[
        create-link-to selected-candidate
      ]
    ]
    update-appearance-of self
  ]

  if is-internal-recruitment[                                    ;; If the selected candidate is internal, we place the next vacancy in it's spot
    ask the-vacancy[
      set xcor next-vacancy-x
      set ycor next-vacancy-y
      set org-level next-vacancy-org-level
      set org-weight next-vacancy-org-weight
      create-link-to next-vacancy-manager
      if next-vacancy-direct-reports != nobody[
        ask next-vacancy-direct-reports[
          create-link-to the-vacancy
        ]
      ]
    ]
  ]
  if not is-internal-recruitment[
    ask the-vacancy [die]
  ]
  set selected-candidate nobody
end

to recruit-for [the-vacancy]
  ask externals [die]
  set candidates nobody
  set selected-candidate nobody

  let recruiting-manager one-of [out-link-neighbors] of the-vacancy
  ifelse ([org-level] of the-vacancy = OrgLevels)[                   ;; If we are at the bottom of the org chart, source external candidates
    source-external-canditates-for the-vacancy
  ][
    source-internal-canditates-for the-vacancy recruiting-manager    ;; If the vacancy is on any other level, we source internally
  ]
  select-candidate-by recruiting-manager
  place-selected-candidate-in the-vacancy recruiting-manager
end

to calculate-org-competence
  set org-competence 0
  set max-org-competence 0
  set abs-org-competence 0
  ask employees[
    set abs-org-competence abs-org-competence + (competence * org-weight)
    set max-org-competence max-org-competence + (100 * org-weight)
  ]
  set org-competence (abs-org-competence / max-org-competence) * 100
end



to Go
  set TraitVisualisation "Rainbow"
  if count vacancies = 0[
    create-a-vacancy
  ]
    if count vacancies = 1[
      recruit-for one-of vacancies
  ]
  calculate-org-competence
  tick
end
@#$#@#$#@
GRAPHICS-WINDOW
195
10
708
524
-1
-1
15.303030303030303
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

SLIDER
15
10
185
43
OrgLevels
OrgLevels
2
5
5.0
1
1
NIL
HORIZONTAL

SLIDER
15
45
185
78
TeamSize
TeamSize
3
7
5.0
1
1
NIL
HORIZONTAL

BUTTON
15
130
115
175
Setup Org
SetupOrg
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
15
330
185
363
Go once
Go
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
15
285
185
320
Setup Employees
SetupEmployees
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
125
130
182
175
N
N
0
1
11

CHOOSER
15
230
192
275
RecruitmentStrategy
RecruitmentStrategy
"Competence" "Random" "Affinity" "Affinity or Competence" "Discernment"
0

PLOT
195
540
710
690
Organisation Competence and Diversity
NIL
NIL
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"competence" 1.0 0 -16777216 true "" "plot org-competence"
"diversity" 1.0 0 -13840069 true "" "plot  variance [halo] of employees"

BUTTON
15
375
185
408
Go
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
720
10
920
260
Top Level Diversity
NIL
NIL
0.0
100.0
0.0
100.0
true
false
"set-plot-x-range 0 100\nset-plot-y-range 0 count employees with [org-level = 2]\nset-histogram-num-bars 11" ""
PENS
"default" 1.0 1 -5298144 true "" "histogram [halo] of employees with [org-level = 2]"

PLOT
720
280
920
525
Bottom Level Diversity
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 100\nset-plot-y-range 0 count employees with [org-level = OrgLevels]\nset-histogram-num-bars 11" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [halo] of employees with [org-level = OrgLevels]"

CHOOSER
15
80
185
125
OrgLayout
OrgLayout
"Spring Network" "Radial Network" "Grid"
2

@#$#@#$#@
## WHAT IS IT?

A model to explore how different ways to select employees for promotion, might impact the composition of the overall organisation.

## HOW IT WORKS

First an organisation is set up.
Then when the model is run, it does the following:

* Check if there are vacancies

* If there are none, create a vacancy by selecting an employee at random and replacing with a vacancy.

* Recruit, internally if the vacancy is on anything but the bottom level, otherwise externally.

* In the recruitment, the recruiting managers compare the candidates (existing internal employees or in the external case, temporarily spawned invisible external candidates)

* The way by which the sucessful candidate is chosen is one of the following:

	- **Competence:** This represents the best case situation, omniscient recruiting managers, who are "blind" to the halo trait. This results in high competence paired with diversity in regards the the halo trait.

	- **Random:** This represents the worst case, choosing randomly who to recruit, this result in lowe competence and diversity in the halo trait.

	- **Affinity:** In this strategy the recruiting manager selects the candidate most similar to them in regards to the halo trait, not paying any attention to competence.

	- **Affinity or Competence:** This represents a world where half of the recruiting managers use the strategy "Competence" and the other half "Affinity. 

	- **Discernment:** Perhaps more realistic than those above, this strategy means that the "Discernment trait" that all employees (hence also all managers) are assigned in a similar fashion to the competence and halo traits, decides how likely it is that a recruiting manager can discern between the competence trait and halo traits of the candidates,



## HOW TO USE IT

* By selecting _Number of levels_ and _Team Size_ you define the structure of the organisation. Team size is the same for all teams, both bottom level teams and management teams alike.

* Use _OrgLayout_ to select how the organisation will be visualised.
**This has no effect in how the model works**, but might help you visually see certain phenomena.

	- "Spring Network" is useful for small organisations.

	- "Radial Network" might help look at clustering when modelling bigger organisations,

	- "Grid" is best for general use with bigger organisations.

* Then you click _Setup Org_ to create and the organisation and layout all employees in the world. You can see the total numbers of employees as _N_. If you have selected a network layout, the top manager (CEO) will be visible as a red dot. And all reporting lines will also be visible. If you instead chose the grid layot this elements are hidden.

* Now, the model is ready to run. To run it once, and perform one recruitment, you can press _go once_. After that you will see that the shape for one employee has been changed to a filled shape.

* To run the model continuously and see how things develop, you can press _go_ button.

* While the model is running you can change the selected _RecruitmentStrategy_ and all upcoming recruitments will be made with that strategy,

* If you want to start over, you can press _Setup Employees_. This will not change the organisation structure, but it will reset the properties of all the employees to the default settings. 

## THINGS TO NOTICE

What is visualised in the world:

* The shape of the employees varies by the organisation level. In the grid view, the employees are laid out starting with the top level in the top left corner. Moving downwards in a sweeping pattern going throug all levels sequentially.

* When the organisation is created, when a set of external candidates are created, or when the button _Setup Employees_ is pressed, all employees are assigned two traits by random normal distribution: _Competence_ and _Halo_. Halo is a placeholder for any kind of trait that does not affect work as directly as competence. But is yet salient.These two traits are visualised as such:

	- Comptence is shown in the size of each employee.

	- Halo is represented by the different colors of the employees

So when running the model, you can observe how different recruitment strategies affect the distrubution of sizes and colors.


## THINGS TO TRY

Run the model and see how different recruitment strategies affect the overall competence in the organisation. 
The _Organisation Competence_ value plotted is calculated by weighting the competence trait of each employee by multiplying by the number of employees "in their charge" and then adding them up.

You can also observere the distribution of the halo trait in the top level management on the _Top Level Diversity_ graph. I you have the model running, and the recruitment strategy "Affinity" selected. This distrubution typically settles down on one of the three central bins in the distribution. When it settles, you can press _Setup Employees_ to restart the model with a random distribution of traits, you can then see that the distribution settles down again, but not necesarily with a peak in the center.

## EXTENDING THE MODEL

In many ways, this model is just a starting point that might help model different recruitment heuristics, so implementing different strategies for the recruiting manager is the most obviuod extension.

The aim when I started building this model was to include a property in each employee that records their experience of the recruitments that take place in their part of the organisation. This variable holding "percieved fairness" could be used as a parameter to motivate employees to leave the organisation. An employee would only "experience" recruitments in their own team and their own managers team, and a recruitment would positively affect their "percieved fairness" if the employee would have reached the same verdict as the recruiting manager.

This fairness score is an extension that there are however several things that I think could improve the quality of the model as it is today:

* Calibrating the probablity of employees leaving with data from real workd organisations. Idelly stratified by organisation level. If in the real world there is less mobility in hihger levels, that would perhaps re-enforce the tendency shown already in this model for diversity to be higher in the lowest organisation level.

* In this model there are no seniors who are not managers, this makes the model much easier to build. But has low face validity.

* We only recuit externally at the lowest level, then only external candidates are considered. To better reflect the real world, externals could be added to the candidate pool also on higher levels.

* We do not consider lateral moves or demotions, these should be added with a suitable (lower) probability to better reflect real organisations.

* The way overall competence is measured, weighting managers by their influence, has some face value, but is utterly arbitrary.

Also, if anyone were to really test these different recruitment strategies, more/better metrics would perhaps needed. And perhaps the ability to run a certain amout of ticks or until a certain metric has stabilised. It would be interesting to run experiments with BehaviourSpace to compare different recruitment strategies.

What would interest me the most, is to look into research on how we assess candidates and see if findings there can inspire/inform simplified versions of these selection heursitics.

## NETLOGO FEATURES

Recursion is used.
Some sliders are not only used to setup but also referenced during the run, this feels a bit risky.

I struggled **a lot** with laying out the agents on a grid. I have used modulus for similar things in the past (in other languages). But could not get it right. Even without the mod operation, it's still nog right. Would be nice to see someone do it properly.

## RELATED MODELS

My inability to find similar models can mean that this is not a good way to model this phenomenon. There might also be models like this, and better, in the drawers out there.

## CREDITS AND REFERENCES

This was created from scratch by marcus@samora.se and stackoverflow :)
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
1
@#$#@#$#@
