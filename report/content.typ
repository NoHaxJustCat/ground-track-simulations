// All numbers come from output/results.json, written by simulations/pass_statistics.py
#let res = json("/output/results.json")
#let p = res.passes
#let r(x, d: 1) = str(calc.round(x, digits: d))
#let mins(s, d: 2) = r(s / 60, d: d)
#let dl-mixed = res.downlink.find(x => x.name == "Mixed 25/75")
#let ul-chunk = res.uplink.find(x => x.name == "Code / picture chunks")
#let ver = json("/output/verification.json")
#let iss = ver.iss
#let yr = ver.dvs_year

#set list(spacing: 1em)

#show table.cell: it => {
  set text(font: "Droid Sans Armenian")
  it
}

#let vol-table(rows) = table(
  columns: (auto, auto, auto, auto, auto, auto, auto),
  stroke: 0.5pt,
  align: (left, center, center, center, center, center, center),
  table.hline(stroke: 1pt),
  [*Scenario*], [*Useful rate* \ [B/s]], [*Short pass* \ P10 [KB]], [*Mean pass* \ [KB]], [*Long pass* \ P90 [KB]], [*Low day* \ P10 [MB]], [*Mean day* \ [MB]],
  table.hline(stroke: 1pt),
  ..rows.map(x => (
    [#x.name], [#r(x.rate_Bps, d: 0)], [#r(x.per_pass_p10_KB, d: 0)], [#r(x.per_pass_mean_KB, d: 0)],
    [#r(x.per_pass_p90_KB, d: 0)], [#r(x.per_day_p10_MB, d: 2)], [*#r(x.per_day_MB, d: 2)*],
  )).flatten(),
  table.hline(stroke: 1pt),
)

= Introduction

This report estimates how much data the Da Vinci Satellite can exchange with the Delft ground station. The DVS
Data Budget @dvs_data_budget_2026 derives the useful data rate from the TRXVU transceiver @isis_trxvu_icd and the
AX.25 frame structure, but treats the contact time as an assumption (three passes of 10 min per day). Here the
contact time is instead obtained from an orbit propagation, and combined with the data rates of the link budget
@dvs_link_budget to give an estimate of the volume that can be transmitted on the downlink and on the uplink.

The work consists of three parts:
- a review of the existing ground-track scripts, with corrections to the visibility and pass-extraction logic;
- a one-year simulation of the passes over Delft, giving the statistical distribution of pass durations;
- the conversion of the simulated contact time into a data volume per pass and per day.

== Assumptions

The following assumptions have been adopted for this work:

- A single ground station in Delft is used, and every pass above the elevation mask is scheduled and used.
- The baseline elevation mask is 10°, as assumed in the data budget @dvs_data_budget_2026. The link budget closes
  with positive margin at this elevation (@sec:link).
- Passes shorter than #r(res.inputs.min_pass_duration_s / 60, d: 0) min are not scheduled, as the time needed
  for acquisition and synchronisation leaves too little useful contact. This removes #p.n_too_short of the
  #(p.n_passes + p.n_too_short) passes above the mask. The data budget does not define such a threshold; it is an
  assumption of this report.
- The fraction of each pass usable for data transfer is $f_"eff" = 0.8$, as in the data budget, to account for
  acquisition, synchronisation and protocol handshaking.
- The transceiver is full duplex (separate VHF receiver and UHF transmitter), so uplink and downlink use the
  same contact time.
- Frames lost to bit errors are counted as lost data; the retransmission strategy is not modelled.
- No terrain or local obstructions are considered beyond the elevation mask.
- Drag uses the default TudatPy atmosphere, which corresponds to the US Standard Atmosphere 1976 (moderate solar
  activity). The real decay depends on the solar activity in 2028 and is the main uncertainty on the yearly
  statistics (@sec:verification).

= Simulation Model

== Orbit Propagation

The orbit is propagated with TudatPy @tudatpy using the scripts in `simulations/`. The inputs are listed in
@tab:sim. A full year is simulated, so that every phasing between the ground track, the station and the
precessing orbital plane is sampled, giving #p.n_passes passes.

#figure(
  table(
    columns: (auto, auto),
    stroke: 0.5pt,
    align: (left, left),
    table.hline(stroke: 1pt),
    [*Parameter*], [*Value*],
    table.hline(stroke: 1pt),
    [Initial orbit], [$a = 6890$ km, $e = 0.010$, $i = 52 degree$, $omega = Omega = theta = 0$],
    [Altitude over the year], [#r(res.sim.alt_min_km, d: 0) – #r(res.sim.alt_max_km, d: 0) km],
    [Spacecraft], [2.2 kg, $A = 0.0273$ m², $C_D = 2.2$, $C_R = 1.2$],
    [Force model], [Earth SH 5×5, drag, Sun and Moon point mass, SRP],
    [Integrator], [RK4, fixed step of #r(res.sim.step_s, d: 0) s],
    [Simulated period], [#res.sim.start to #res.sim.end (#r(res.sim.days, d: 0) days)],
    [Ground station], [Delft, 52.0° N, 4.4° E, on the WGS84 ellipsoid],
    [Elevation mask], [#r(p.min_elevation_deg, d: 0)° (baseline)],
    table.hline(stroke: 1pt),
  ),
  caption: [Simulation inputs.],
) <tab:sim>

At every step the elevation of the satellite above the local horizon of the station is computed, and a pass is
defined as an interval in which the elevation is above the mask. The start and end times of each pass are found
by linear interpolation at the mask crossing. With a 10 s step the pass durations agree with a 2 s reference
run to within 0.2 s, so the step size does not limit the accuracy.

== Review of the Original Scripts

The original scripts were checked before producing the results. The propagation itself (environment,
accelerations, initial state and integrator) was found to be sound. The following issues in the visibility and
pass-extraction logic were corrected:

+ *Elevation mask.* Visibility was defined as a zenith angle of at most 75°, i.e. an elevation mask of 15°,
  while the data budget and link budget assume 10°. The mask is now an explicit parameter with a default of 10°.
+ *Station position.* The station was placed on a sphere of mean radius, with a geocentric vertical. At 52°
  latitude this places the station about 6 km too high and tilts the local vertical by about 0.19°. The station is
  now placed on the WGS84 ellipsoid @wgs84 and the elevation is measured from the ellipsoid normal.
+ *Time resolution.* Pass start and end times were taken at sample points, with an error of up to one step at
  each edge. They are now interpolated at the mask crossing.
+ *Truncated passes.* A pass in progress at the start or end of the simulation window was counted as a short
  pass, which biased the mean duration low. Such passes are now discarded.
+ *Duplicated code.* The calendar script contained its own copy of the pass detection. Both scripts now use a
  shared function, which is checked against an analytic case in `simulations/test_passes.py`.

= Pass Statistics

== Pass Duration Distribution

@fig:dist shows the distribution of the duration of the #p.n_passes usable passes above #r(p.min_elevation_deg, d: 0)°
(longer than #r(res.inputs.min_pass_duration_s / 60, d: 0) min),
together with the fitted normal distribution. The satellite passes over Delft
#r(p.passes_per_day, d: 2) times per day on average, for a mean of #mins(p.mean_s) min per pass and a total of
#r(p.contact_s_per_day / 60) min of contact per day.

#figure(
  image("/output/pass_duration_distribution.pdf", width: 90%),
  caption: [Distribution of pass durations above #r(p.min_elevation_deg, d: 0)° elevation over one year, with
    the fitted normal distribution ($mu$ = #mins(p.mean_s) min, $sigma$ = #mins(p.std_s) min).],
) <fig:dist>

The distribution is not exactly normal: it is bounded above by the duration of an overhead pass
(#mins(p.max_s) min) and is skewed towards the long passes, with a tail of short, low-elevation passes. The normal
fit is therefore a convenient summary, but the data volumes in @sec:volume use the simulated durations directly.
The median pass lasts #mins(p.median_s) min; 10 % of the passes are shorter than #mins(p.p10_s) min and 10 % are
longer than #mins(p.p90_s) min.

== Daily Contact

Since data is generated and planned on a daily basis, the passes are also grouped per UTC day (by the start time
of the pass). @fig:perday shows that every day has between #r(p.passes_per_day_min, d: 0) and
#r(p.passes_per_day_max, d: 0) usable passes, and #r(p.passes_per_day, d: 2) on average
($sigma$ = #r(p.passes_per_day_std, d: 2)). The resulting total contact time per day (@fig:contactday) has a mean
of #mins(p.contact_s_per_day, d: 1) min ($sigma$ = #mins(p.contact_s_per_day_std, d: 1) min), ranging from
#mins(p.contact_s_per_day_min, d: 1) min to #mins(p.contact_s_per_day_max, d: 1) min. On 90 % of the days the
contact time is at least #mins(p.contact_s_per_day_p10, d: 1) min, which is used below as a "low day" for planning.

#figure(
  image("/output/passes_per_day_distribution.pdf", width: 80%),
  caption: [Distribution of the number of usable passes per day over one year, with the fitted normal distribution.],
) <fig:perday>

#figure(
  image("/output/contact_per_day_distribution.pdf", width: 80%),
  caption: [Distribution of the total pass duration per day over one year, with the fitted normal distribution.],
) <fig:contactday>

The daily contact time is closer to a normal distribution than the single-pass duration, because it is the sum of
several passes. It is nevertheless bimodal around 27 min and 33 min, corresponding to days with four and five
passes, with a small tail of six-pass days above 40 min.

== Effect of the Elevation Mask

@tab:sweep shows how the pass statistics change with the elevation mask. A lower mask gives both more passes
and longer passes, so the daily contact time is very sensitive to the local horizon of the station.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto, auto, auto),
    stroke: 0.5pt,
    align: center,
    table.hline(stroke: 1pt),
    [*Mask*], [*Passes*], [*Per day*], [*Mean* \ [min]], [*σ* \ [min]], [*P10* \ [min]], [*P90* \ [min]], [*Contact* \ [min/day]],
    table.hline(stroke: 1pt),
    ..res.elevation_sweep.map(e => (
      [#r(e.min_elevation_deg, d: 0)°], [#e.n_passes], [#r(e.passes_per_day, d: 2)],
      [#mins(e.mean_s)], [#mins(e.std_s)], [#mins(e.p10_s)], [#mins(e.p90_s)],
      [#r(e.contact_s_per_day / 60)],
    )).flatten(),
    table.hline(stroke: 1pt),
  ),
  caption: [Pass statistics over one year for different elevation masks.],
) <tab:sweep>

= Verification <sec:verification>

The pass prediction was verified in three independent ways, using `simulations/verify_passes.py`. The results
are stored in `output/verification.json`.

== Comparison with Heavens-Above (ISS)

The International Space Station has an orbit very similar to the DVS one (51.6° inclination, about 420 km
altitude), and its passes are published by Heavens-Above @heavens_above, which propagates the public two-line
elements with the SGP4 model @vallado_sgp4. All #iss.n_ref_passes ISS passes above 10° over Delft between 18 and
27 October 2026 were compared with two predictions made from the same two-line elements @celestrak:

+ *Geometry only.* The ISS positions are computed with SGP4 (Skyfield @skyfield), and the elevation and pass
  extraction of this work are applied to them. This isolates the station model, the elevation computation and the
  pass extraction.
+ *Full pipeline.* The ISS state at the TLE epoch is propagated with the TudatPy model of this work (with the
  drag area derived from the TLE drag term), followed by the same elevation and pass extraction.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    stroke: 0.5pt,
    align: (left, center, center, center),
    table.hline(stroke: 1pt),
    [*Prediction*], [*Rise time* \ mean / max [s]], [*Set time* \ mean / max [s]], [*Duration* \ mean / max [s]],
    table.hline(stroke: 1pt),
    ..(("Geometry only", iss.geometry_only), ("Full pipeline, first 2 days", iss.full_pipeline_first_2_days),
       ("Full pipeline, 9 days", iss.full_pipeline)).map(((n, x)) => (
      [#n],
      [#r(x.rise.mean_abs_s) / #r(x.rise.max_abs_s)],
      [#r(x.set.mean_abs_s) / #r(x.set.max_abs_s)],
      [#r(x.duration.mean_abs_s) / #r(x.duration.max_abs_s)],
    )).flatten(),
    table.hline(stroke: 1pt),
  ),
  caption: [Absolute differences with the #iss.n_ref_passes ISS passes over Delft listed by Heavens-Above.],
) <tab:iss>

#figure(
  image("/output/verification_iss.pdf", width: 100%),
  caption: [Differences in rise time and pass duration with respect to Heavens-Above for each ISS pass.],
) <fig:iss>

The geometry agrees with Heavens-Above to within #r(iss.geometry_only.duration.max_abs_s) s, which is the
rounding of the published times to whole seconds (@tab:iss). The full pipeline agrees to within a few seconds
during the first two days. Afterwards, the predicted passes drift slowly later, by about 3 s per day
(@fig:iss), because the TudatPy atmosphere and the SGP4 drag term decay the orbit at slightly different rates.
The pass *durations*, which are what matter for the data budget, remain within
#r(iss.full_pipeline.duration.mean_abs_s) s on average over the whole window. The largest duration difference
(#r(iss.full_pipeline.duration.max_abs_s, d: 0) s) occurs for a grazing pass with a maximum elevation of only 11°,
whose duration is very sensitive to small orbit differences.

== Comparison with SGP4 over One Year (DVS)

The DVS orbit was also propagated over 2028 with SGP4, and the passes were found with Skyfield's own rise and set
search, independent of the code of this work. The SGP4 mean elements were set equal to the TudatPy initial
elements. Two cases were run: without drag, which isolates the geometry and gravity model, and with the SGP4 drag
term computed from the DVS ballistic coefficient.

#figure(
  table(
    columns: (auto, auto, auto, auto),
    stroke: 0.5pt,
    align: (left, center, center, center),
    table.hline(stroke: 1pt),
    [*Quantity*], [*TudatPy* \ (this work)], [*SGP4* \ no drag], [*SGP4* \ with drag],
    table.hline(stroke: 1pt),
    [Passes per day], [#r(yr.tudat.passes_per_day, d: 2)], [#r(yr.sgp4_no_drag.passes_per_day, d: 2)], [#r(yr.sgp4_drag.passes_per_day, d: 2)],
    [Mean pass duration [min]], [#mins(yr.tudat.mean_s)], [#mins(yr.sgp4_no_drag.mean_s)], [#mins(yr.sgp4_drag.mean_s)],
    [Longest pass [min]], [#mins(yr.tudat.max_s)], [#mins(yr.sgp4_no_drag.max_s)], [#mins(yr.sgp4_drag.max_s)],
    [Contact per day [min]], [#mins(yr.tudat.contact_s_per_day, d: 1)], [#mins(yr.sgp4_no_drag.contact_s_per_day, d: 1)], [#mins(yr.sgp4_drag.contact_s_per_day, d: 1)],
    [Altitude at year end [km]], [#r(res.sim.alt_end_km, d: 0) (perigee)], [#r(yr.sgp4_no_drag.alt_end_min_km, d: 0) – #r(yr.sgp4_no_drag.alt_end_max_km, d: 0)], [#r(yr.sgp4_drag.alt_end_min_km, d: 0) – #r(yr.sgp4_drag.alt_end_max_km, d: 0)],
    table.hline(stroke: 1pt),
  ),
  caption: [Yearly pass statistics of the DVS orbit over Delft (10° mask, passes of at least 2 min).],
) <tab:sgp4>

#figure(
  image("/output/verification_dvs.pdf", width: 85%),
  caption: [Pass duration distribution over 2028 from TudatPy and from SGP4 without drag.],
) <fig:sgp4>

Without drag, SGP4 gives the same number of passes per day to within
#r(100 * calc.abs(yr.sgp4_no_drag.passes_per_day / yr.tudat.passes_per_day - 1), d: 1) % and the same shape
of the duration distribution (@fig:sgp4). Its passes are
#r(100 * (yr.sgp4_no_drag.mean_s / yr.tudat.mean_s - 1), d: 0) % longer, which is consistent with the slow
decay included in the TudatPy run: the SGP4 orbit stays at its initial altitude. With the SGP4 drag term, on the
other hand, the orbit decays to about #r(yr.sgp4_drag.alt_end_min_km, d: 0) – #r(yr.sgp4_drag.alt_end_max_km, d: 0) km within the year, and the contact time drops to
#mins(yr.sgp4_drag.contact_s_per_day, d: 0) min per day. The SGP4 density profile is fixed and not intended for
long-term decay prediction, so this case is a pessimistic bound rather than a prediction. It shows, however, that
the orbit decay is the dominant uncertainty on the yearly statistics: the geometry and pass extraction are
verified, but the altitude at which the satellite will fly is not. A lifetime analysis with a solar-activity-dependent
atmosphere (e.g. NRLMSISE-00 with predicted solar flux) is recommended to refine the yearly figures.

== Analytical Maximum Pass Duration

For a circular orbit at altitude $h$, the longest pass, directly overhead, lasts @smad

$ T_"max" = P / pi (pi/2 - epsilon - eta), quad sin eta = (R_E cos epsilon) / (R_E + h) $ <eq:tmax>

where $P$ is the orbital period and $epsilon$ is the elevation mask. At the highest altitude reached during the
year (#r(res.sim.alt_max_km, d: 0) km) this gives #mins(ver.analytic.t_max_at_max_alt_s) min, and at the lowest
(#r(res.sim.alt_min_km, d: 0) km) #mins(ver.analytic.t_max_at_min_alt_s) min. @eq:tmax neglects the rotation of the
Earth. Since the station latitude is close to the inclination, the longest passes occur near the northern turning
point of the orbit, where the satellite moves eastwards together with the station. This reduces the relative
angular rate by a factor $1 - (omega_E \/ n) cos i$ and lengthens the pass up to
#mins(ver.analytic.t_max_at_max_alt_rotating_s) min. The longest simulated pass,
#mins(ver.sim_max_duration_s) min, lies between these two bounds.

= Data Volume <sec:volume>

== Link Budget Check <sec:link>

The link budget @dvs_link_budget is computed at 500 km altitude for elevations from 5° to 90°. The UHF downlink
at #r(res.inputs.downlink_rate, d: 0) bit/s has a link margin of +3.3 dB at 5° and +5.2 dB at 10°, after a 3 dB
system margin and a required $E_b"/"N_0$ of 10.4 dB. The VHF uplink at #r(res.inputs.uplink_rate, d: 0) bit/s
has a margin of more than 30 dB. The link therefore closes over the whole pass above the 10° mask, and the full
data rate can be used for the entire contact.

== Method

Following the data budget @dvs_data_budget_2026, the useful volume transferred during a pass of duration
$T_"pass"$ is

$ V_"pass" = R_"phys" dot eta dot (1 - "PER") dot T_"pass" dot f_"eff" $ <eq:vpass>

where $R_"phys"$ is the data rate from the link budget, $eta$ is the payload efficiency of the frame type (payload
bytes over total frame bytes, including the AX.25 metadata and the frame header) and
$"PER" = 1 - (1 - "BER")^L$ is the packet error rate for a frame of $L$ bits at $"BER" = 10^(-5)$. The daily
volume is obtained by replacing $T_"pass"$ with the simulated contact time per day, both for the mean day and
for a low day (10th percentile of the daily contact time). The scenarios and frame
sizes are taken from the data budget: for the downlink, telemetry frames (30 B payload in 60 B), picture chunks
(64 B in 88 B) and a mixed case with 25 % telemetry and 75 % picture chunks by time; for the uplink, code or picture
chunks (64 B in 95 B) and full-size frames (193 B in 218 B). As in the data budget, 1 KB = 1024 B and
1 MB = 1024 KB.

== Downlink

#figure(
  vol-table(res.downlink),
  caption: [Downlink data volume (UHF, #r(res.inputs.downlink_rate, d: 0) bit/s, #r(p.min_elevation_deg, d: 0)° mask).],
) <tab:dl>

In the nominal mixed scenario the satellite can downlink about *#r(dl-mixed.per_pass_mean_KB, d: 0) KB in an
average pass* and *#r(dl-mixed.per_day_MB, d: 2) MB per day* (@tab:dl). Short passes (P10) still carry
#r(dl-mixed.per_pass_p10_KB, d: 0) KB, which is enough for a full telemetry dump.

== Uplink

#figure(
  vol-table(res.uplink),
  caption: [Uplink data volume (VHF, #r(res.inputs.uplink_rate, d: 0) bit/s, #r(p.min_elevation_deg, d: 0)° mask).],
) <tab:ul>

When uploading code or pictures in 64-byte chunks, about *#r(ul-chunk.per_pass_mean_KB, d: 0) KB per average pass*
and *#r(ul-chunk.per_day_MB, d: 2) MB per day* can be uplinked (@tab:ul). The uplink is limited by its lower data
rate rather than by the link margin.

== Comparison with the Data Budget

- *Contact time.* The data budget assumed 3 × 10 min = 30 min per day. The simulation gives
  #r(p.passes_per_day, d: 2) passes of #mins(p.mean_s) min on average, i.e. #r(p.contact_s_per_day / 60) min per
  day at a 10° mask. The data budget has no minimum pass duration; the 2 min threshold used here removes only
  #r(100 * p.n_too_short / (p.n_passes + p.n_too_short), d: 1) % of the passes and has a negligible effect on the
  daily contact time.
- *Uplink data rate.* The data budget uses 9600 bit/s for the uplink, while the link budget is computed at
  2400 bit/s. This report follows the link budget. At 9600 bit/s the uplink volumes would be four times higher,
  and the link would still close with about 25 dB margin.
- *Packet error rate.* The data budget quotes a PER of about 1.6 % for a 235-byte frame, while
  $1 - (1 - 10^(-5))^1880 = 1.86 %$. Frame losses are included here and reduce the volumes by 0.6 % to 2 %.

= Conclusion

A one-year propagation of the Da Vinci Satellite orbit gives #r(p.passes_per_day, d: 2) passes per day over Delft
above 10° elevation, with a mean duration of #mins(p.mean_s) min (σ = #mins(p.std_s) min) and
#r(p.contact_s_per_day / 60) min of contact per day. With the data rates of the link budget and the frame
overheads of the data budget, the expected useful data volume is:

#figure(
  table(
    columns: (auto, auto, auto, auto),
    stroke: 0.5pt,
    align: center,
    table.hline(stroke: 1pt),
    [*Link*], [*Scenario*], [*Per pass* [KB]], [*Per day* [MB]],
    table.hline(stroke: 1pt),
    [Downlink], [#dl-mixed.name], [#r(dl-mixed.per_pass_mean_KB, d: 0)], [*#r(dl-mixed.per_day_MB, d: 2)*],
    [Uplink], [#ul-chunk.name], [#r(ul-chunk.per_pass_mean_KB, d: 0)], [*#r(ul-chunk.per_day_MB, d: 2)*],
    table.hline(stroke: 1pt),
  ),
  caption: [Expected data volume for nominal operations.],
) <tab:summary>

The pass prediction was verified against the published ISS passes over Delft (agreement within about 1 s on the
geometry), against an independent SGP4 propagation over one year (within 3.5 % on the daily contact time when drag is
excluded), and against the analytical maximum pass duration. These values replace the assumed contact parameters
of the data budget. The main remaining uncertainties are the orbit decay over the mission, the usable fraction of
each pass ($f_"eff"$), the actual horizon mask of the Delft station, and the uplink data rate, which should be
aligned between the data budget and the link budget.
