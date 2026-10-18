#let dod = "DoD"

#set list(spacing: 1em)

#show table.cell: it => {
  set text(font: "Droid Sans Armenian")
  it
}

= Introduction

This report analyzes the power generation performance of the Da Vinci Satellite. While the spacecraft features an Attitude and Orbit Control Subsystem, the subsystem functionality is primarily dedicated to payload image acquisition and de-tumbling maneuvers within safe mode. Therefore, the satellite is modeled as being in an uncontrolled tumbling state throughout the majority of the mission.

The principal objective of this investigation is to establish a conservative baseline value for use in the Power Budget and Power Simulations Report. Prior assessments utilized an average power value derived from a random sampling of points on a sphere, which did not consider temperature fluctuations and end-of-life degradation. This updated report introduces a more comprehensive model that integrates thermal effects, lifetime performance loss, and a deterministic equal-area spherical sampling strategy.

Sun-incidence directions are sampled over the full unit sphere using a grid that is uniform in $sin theta$, ensuring equal solid-angle weighting without the statistical variability of random methods. For each sampled direction, the instantaneous electrical power output is evaluated accounting for cell temperature and radiation-induced degradation. The tumbling-average power is then computed as the arithmetic mean over all sampled directions.
== Assumptions
The following assumptions have been adopted for this work:

- The rotation period is assumed to be significantly shorter than the duration of the sunlit orbital pass, a condition consistent with the expected tumbling rate of 1 to 10 degrees per second.
- The Earth albedo effect has been excluded from calculations, both for temperature effects and power generation. This leads to a conservative result.
- Internal heat dissipation from onboard components is neglected in the temperature estimation of the solar panels. The thermal balance of the panels is driven exclusively by incident solar radiation and infrared emissivity. 
- A wiring efficiency of 98% has been considered.
- It has been considered that the solar cell will have a MPP tracker that allows the system to extract the maximum power available. The efficiency of the MPP derives from the ISIS Space Type B EPS, at around 87.5% at 5V.

This methodology ensures that the orbital power average provides a reliable lower bound for mission planning and system sizing.

= Solar Cell Model

The DVS satellite is equipped with high-efficiency TJ 3G30-Advanced III–V triple junction Gallium Arsenide solar cells manufactured by AZUR SPACE. 

To maintain accuracy throughout the mission, the model utilises linear interpolation between given data points to accounts for the degradation of maximum power point voltage and current as a function of electron fluence. As radiation exposure increases, the solar cell's internal structure degrades, leading to a drop in voltage and a slight increase in current. The following data was extracted from the datasheet. @azurspace_3g30_advanced_4x8


#figure(
  caption: [Typical cell electrical performance.],
  table(
    columns: (auto, 2cm, 2cm, 2cm, 2cm, 2cm, 2cm),
    inset: 6pt,
    [*Fluence (e/cm²)*],[BOL (0)],[5E13],[2.5E14],[5E14],[1E15],[1E16],
    [$V_("mp")$ - [mV]],[2411],[2336],[2298],[2262],[2230],[2127],
    [$I_("mp")$ - [mA]],[504],[501],[496],[494],[484],[360],
  )
) <tab:typ_cell_electrical>

#figure(
  caption: [Typical cell temperature coefficients.],
  table(
    columns: (auto, 2cm, 2cm, 2cm, 2cm),
    inset: 8pt,
    [*Fluence (e/cm²)*],[BOL (0)],[2.5E14],[5E14],[1E15],
    [$(d V_("mp")) / (d T)$ - $[("mV")/(degree C)]$],[-6.7],[-6.8],[-7.1],[-7.2],
    [$(d I_("mp")) / (d T)$ - $[("mA")/(degree C)]$],[0.24],[0.20],[0.24],[0.28],
  )
) <tab:typ_cell_temp>


== Configurations

Three main solar cells configurations have to be analysed in the simulations: a) all the solar panels working, b) $-"Z"$ two solar panels removed, c) $+"Y"$ two solar panels removed and d) two solar panels from $+"Y"$ and $-"Z"$ removed respectively. The reasons behind the configurations is explained in the Solar Panels Replacement and/or Removal Options Report @gallo_lopez_dvs_solar_panel_options_2026. This report, alongside the Power Simulations Report, has the scope to chose which of the four is the most adequate for the mission.


#grid(
  columns: (1fr, 1fr),
  gutter: 12pt,
  figure(
    table(
      inset: 8pt,
      columns: (auto, auto, auto, auto, auto, auto, auto),
      [side],[+X],[-X],[+Y],[-Y],[+Z],[-Z],
      [\# cells],[4],[4],[4],[4],[2],[2],
    ),
    caption: [*a)* All the panels working]
  ),
  figure(
    table(
      inset: 8pt,
      columns: (auto, auto, auto, auto, auto, auto, auto),
      [side],[+X],[-X],[+Y],[-Y],[+Z],[-Z],
      [\# cells],[4],[4],[4],[4],[2],[*0*],
    ),
    caption: [*b)* Two Z- panels lost]
  ),
  figure(
    table(
      inset: 8pt,
      columns: (auto, auto, auto, auto, auto, auto, auto),
      [side],[+X],[-X],[+Y],[-Y],[+Z],[-Z],
      [\# cells],[4],[4],[*2*],[4],[2],[2],
    ),
    caption: [*c)*  Two Y+ panels lost]
  ),

  figure(
    table(
      inset: 8pt,
      columns: (auto, auto, auto, auto, auto, auto, auto),
      [side],[+X],[-X],[+Y],[-Y],[+Z],[-Z],
      [\# cells],[4],[4],[*2*],[4],[2],[*0*],
    ),
    caption: [*d)*  Two Y+ and two $-"Z"$ panels lost]
  )
)



== Solar Cell Lifetime Degradation

A simulation on SPENVIS was executed for a orbit with $i = 97 degree$, $Omega = 0$, $h = 600 "km"$ and $e=0$. The report can be accessed at @davinci_eqflux_2025. The Cell settings are shown in @tab:cell_prop.

#figure(
  table(
    columns: 2,
    table.cell(colspan: 2)[Cell: Azur 3G30 (SR-NIEL 21eV)],
table.cell(colspan: 2)[Electron/proton damage ratios:],
[Pmax],[1134.8],
[Voc],[2864.6],
[Isc],[613.4],
table.cell(colspan: 2)[Coverglass],
[material],[SiO2],
[density],[2.32 (g/cm3)]
  ), caption: [AZUR 3G30 key data.]
) <tab:cell_prop>

With a mission lifetime of two years, the following Solar cell damage equivalent fluences were obtained (@tab:fluences).
The Total Fluence obtained through SPENNVIS is roughly 7% of the first provided data point in @tab:typ_cell_electrical. Using a linear interpolation, the power decreases from 1.215 W to 1.211 W, a reduction of 0.33%. 
#figure(
  table(
    align: center + horizon,
    columns: (auto, auto, auto, auto),
    table.header([Coverglass Thickness],[Protons Fluence $Phi_max$], [Electrons Fluence $Phi_max$], [Total Fluence $Phi_max$]),
    [100 \u{03BC}m],[3.484E+12],[2.168E+11],[3.706E+12],
  ), caption: [SPENVIS Fluences],
) <tab:fluences>

== Power Model

In the calculations that follow, the temperature was kept into account using a linear model with the slopes taken directly from @tab:typ_cell_temp. The final value is a linear interpolation with the one at the BOL and the first data point. Note that the reference temperature is $28 degree"C"$ @azurspace_3g30_advanced_4x8. 

#let evaluated(expr, size: 100%) = $lr(#expr|, size: #size)$

$        G_("eff")    = G · cos θ $

       $ V_"mp"_"cell" = V_"mp"_0 + evaluated((d V )/(d T))_(Phi) (T_("cell") - T_("ref")) $

       $ I_"mp"_"cell" = I_"mp"_0 G_("eff")/G_0 + evaluated((d I )/(d T))_(Phi) (T_("cell") - T_("ref")) $

      $ P_"face"   =  V_"mp"_"cell" · I_"mp"_"cell" · n_"cells" · eta_"wiring" $

Where a $eta_"wiring"$ of 0.98 was introduced to account for losses in wiring.


== Temperature Effects

The temperature was obtained through a balance of heat flows for each face.


$ dot(Q)_"emitted"= dot(Q)_"absorbed" $

The emitted heat flow for each side is given by:

$
dot(Q)_"emitted"_i = T^4 dot sigma dot epsilon_"coverglass" dot A_i 
$

Where $epsilon_"coverglass" = 0.86$, as from @qioptiq_cover_glass_datasheet (CMG, AR coating).


The absorbed heat for face is given by:
$
dot(Q)_"absorbed"_i = G dot A_i dot alpha_"solar-cell" dot cos theta_i
$

The albedo has been neglected, both for the temperature and for power generation. Therefore, when the face is not illuminated by the Sun, a temperature of 0 K has been given to the face as a placeholder, since in any case the solar cell is not generating power.

The final temperature for each cell is given by:

$ 
T = root(4,((G dot alpha_"solar-cell" dot cos theta_i)/(sigma dot epsilon_"coverglass" )))
$ <eq:temp>

Where an absorption coefficien of $alpha_"solar-cell" = 0.91 dot 0.30 = 0.637$ has been used, which accounts for the $tilde 30%$ electricity conversion. @azurspace_3g30_advanced_4x8  Is it worth mentioning that the real temperature will be lower due to conduction with the aluminium structure, here neglected for simplicity purposes.

Following is the maximum temperature expected with the given model. Please acknowledge that, compared to data from satellite employing similar solar cells, this temperature is higher @JARA2022108697.

$
T_max =  root(4,((1367 #h(1pt) "W" "m"^(-2) dot 0.637 )/(5.67 dot 10^(-8) #h(1pt) "W" "m"^(-2) "K"^(-4) dot 0.86 ))) = 365.7 "K" = 92.7  degree"C"
$

@fig:face_temp shows how the temperature of each face change with the direction of the Sun. As expected, the temperature gradient is the same for each face, since the temperature does not depend on the area, as can be seen in @eq:temp.

#figure(
  image("images/point_face_temperatures.png", width: 90%), caption: [Temperature of each face with respect to the Sun direction.]
) <fig:face_temp>

== Geometric Averaging Method

The average power generated during a tumbling motion is computed by uniformly
sampling all possible sun-incidence directions over the unit sphere and
averaging the resulting power output across all samples.

Sun directions are parameterised in spherical coordinates by elevation angle
$theta in [-pi\/2, pi\/2]$ and azimuthal angle $phi in [0, 2pi)$. To ensure
equal solid-angle weighting, the elevation grid is made uniform in $sin theta$
rather than in $theta$ itself. The sample points are therefore defined as

$
sin theta_i = -1 + frac(2(i-1), N_"el" - 1), quad i = 1, dots, N_"el"
$

with $N_"az"$ equally-spaced azimuth angles $phi_j = 2pi j \/ N_"az"$,
$j = 0, dots, N_"az" - 1$. Each pair $(i, j)$ defines a unit sun vector in
the spacecraft body frame:

$
hat(s)_(i j) = mat(cos theta_i cos phi_j; cos theta_i sin phi_j; sin theta_i)
$

The instantaneous electrical power $P(hat(s)_(i j))$ is evaluated for every
sample point by calling `solar_power_output` with the corresponding sun
vector. The tumbling-average power is then the arithmetic mean over all
$N_"el" times N_"az"$ directions:

$
overline(P)_"mean" = frac(1, N_"el" N_"az") sum_(i=1)^(N_"el") sum_(j=1)^(N_"az") P(hat(s)_(i j))
$

Because the grid is uniform in solid angle, every sampled direction contributes
equally and no additional weighting is required.

This approac Nicolò Basso's Typst
Dashboard
h differs fundamentally from an earlier method in which tumbling
was simulated by composing successive quaternion rotations about a set of
sampled spin axes. In that formulation, an initial attitude was rotated through
a set of random angles drawn uniformly from $[0, 2pi)$ for each of a
distribution of rotation vectors generated via a Fibonacci sphere.

= Results

The four configurations were evaluated in MATLAB using the geometric averaging method introduced above. @tab:results summarises the power output for the thermal, degradation-adjusted case together with the corresponding no-thermal BOL and EOL values, making it possible to isolate the effect of temperature and radiation losses across the different configurations.

As a reference, the no-thermal BOL case can be compared with the limit obtained from Cauchy's theorem. For any convex object tumbling randomly in 3D space, its average projected area is exactly $1"/"4$ of its total surface area. Because solar power is directly proportional to the projected area facing the Sun, a tumbling satellite will therefore average about $1"/"4$ of its total installed capacity in the idealised limit.

$ 
P_"cell"_"ideal" = V_("mp0") dot I_("Imp0") approx 1.215 "W"
$


The theoretical ideal averages would be the total power divided by four. For the configuration A, which has a total of 20 solar cells:

$ P_A_"avg" = (20 dot 1.215 "W")/4 = 6.075 "W" $

Keeping into account the $eta = 0.875 dot 0.98$, we obtain 5.21 W, which is close to the no-thermal BOL value of 5.191 W for configuration A that the code outputs. The remaining discrepancy is attributed to the discretisation of the surface grid.



== Sunlit Tumbling Averages

The following set of results presented in @tab:results regard only the fully sunlit case, where the satellite is illuminated over the complete sphere of incidence directions. No eclipse has been kept into consideration: these values are the one meant to be fed into TUDat to obtain the average power generation value over an orbit.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    stroke: 0.5pt,
    align: (center, center, center),
    table.hline(stroke: 1pt),
    table.vline(stroke: 1pt),
    [Config],
      table.vline(stroke: 1pt),
    [Min],[Max],[Avg],
        table.hline(stroke: 1pt),

    [A],[1.784 W],[5.986 W],[4.829 W],
    [B],[1.781 W],[5.986 W],[4.347 W],
    [C],[0.000 W],[5.986 W],[4.342 W],
    [D],[0.000 W],[5.986 W],[3.860 W],
        table.hline(stroke: 1pt),
    table.vline(stroke: 1pt),
    
  ),caption: [Sunlit tumbing average powers of different configurations.]
) <tab:results>

@fig:distribution shows the distribution of power values and the mean for each configuration studied. @fig:heatmap presents the heatmap of the power generated of the different configuration with respect to the direction of the Sun vector. Configuration C and D show that there are some direction for which almost zero power is generated, due to the absence of panels on the -Z side.

For reference purpose only, using @eq:eclipse at 180 km the maximum eclipse fraction is equal to 0.425 at the expected minima operational altitude. Therefore we can expect, as absolute lower bounds, the following values for each configuration: A) 2.776 W, B) 2.499 W, C) 2.496 W and D) 2.219 W.



#figure(
  image("images/point_distribution_all.png"),
  caption: [Distribution of sunlit power values across all sampled incidence directions.]
) <fig:distribution>

#figure(
  image("images/point_heatmap_all.png"),
  caption: [Heatmap of generated power over the Sun-direction sphere.]
) <fig:heatmap>

== Validation

To validate the results obtained for the DVS configuration, a simulation was performed for the SPIRONE 2U Cubesats. This cubesat employs the same AZUR 3G30 solar cells, with a total of 19 cells (4 for +X, -X, +Y, -Y; 2 for +Z and 1 for -Z). The calculated generated power of the satellite was of 2.68 W. @spirone_2024. A configuration file was created on the software for this satellite. The main changes compared to DVS satellite are:
- The different number of cells;
- The electrical parameters of $I_"mp" = 502.9 "mA"$ and $V_"mp" = 2409 "mV"$, provided in @spirone_2024, differ slightly from the one in the datasheet. 
- Degradation for the SPIRONE simulation was neglected.
- A lower efficiency of the MPPT of 85% was used, as given in @spirone_2024.

Using these values, an average sunlit power of 4.5393 W was obtained. Utilising the following formula from literature to calculate the fraction of eclipse, with an orbit altitude of 600 km. @Hakima2020

$ f_e_max = 1/ (180 degree) arccos(sqrt(h^2 + 2h R) / ((R+h) )) = 0.367 $ <eq:eclipse>

The final value power average obtained is of 2.816 W, 5% higher than the results presented in @spirone_2024. 
It is hence clear that, with a margin of 10%, a reasonable and conservative value for the DVS power budget can be obtained to cover this discrepancy.