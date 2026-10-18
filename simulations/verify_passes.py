"""Independent verification of the pass prediction (needs: pip install skyfield).

1. ISS over Delft: Heavens-Above pass table (inputs/) vs
   a) our elevation + pass extraction applied to SGP4 positions (checks geometry only),
   b) our full pipeline: Tudat propagation from the ISS state + elevation + pass extraction.
2. DVS orbit over one year: SGP4 + Skyfield's own rise/set search vs output/results.json.
3. Analytical maximum pass duration (SMAD) vs the simulated maximum.
"""
import csv
import json
import os
from datetime import datetime, timezone

import matplotlib.pyplot as plt
import numpy as np
from sgp4.api import Satrec, WGS72
from skyfield.api import EarthSatellite, load, wgs84
from skyfield.framelib import itrs

from Ground_track_utilities import OUTPUT_DIR, elevation_deg, find_passes, propagate_elevation
from plot_style import BLACK, BLUE, GREY, VERMILION, save

INPUT_DIR = os.path.join(OUTPUT_DIR, "..", "inputs")
lat, lon, min_el = 52.0, 4.4, 10.0          # same station and mask as Heavens-Above query
ts = load.timescale()
station = wgs84.latlon(lat, lon)
mu_earth = 3.986004418e14


def j2000_s(t):
    """Skyfield time -> TDB seconds since J2000, as used by Tudat."""
    return (t.tdb - 2451545.0) * 86400


def to_utc(sec):
    return ts.tdb_jd(2451545.0 + np.asarray(sec) / 86400).utc_datetime()


def match(ref_rise, ref_set, rise, sets):
    """Differences [s] (rise, set, duration) to the nearest predicted pass of each reference pass."""
    out = []
    for r0, s0 in zip(ref_rise, ref_set):
        i = np.argmin([abs((r - r0).total_seconds()) for r in rise])
        out.append(((rise[i] - r0).total_seconds(), (sets[i] - s0).total_seconds(),
                    ((sets[i] - rise[i]) - (s0 - r0)).total_seconds()))
    return np.array(out)


def stats(d):
    return {"mean_abs_s": np.abs(d).mean(), "max_abs_s": np.abs(d).max()}


# ============================== 1. ISS vs Heavens-Above ==============================
with open(os.path.join(INPUT_DIR, "iss_tle.txt")) as f:
    name, l1, l2 = [l.strip() for l in f if not l.startswith("#")][:3]
iss = EarthSatellite(l1, l2, name, ts)

with open(os.path.join(INPUT_DIR, "heavens_above_iss_delft.csv")) as f:
    ha = list(csv.DictReader(f))
# Heavens-Above shows seconds rounded to 1 s, in UTC
parse = lambda d, t: datetime.strptime(f"{d} 2026 {t}", "%d %b %Y %H:%M:%S").replace(tzinfo=timezone.utc)
ha_rise = [parse(r["date_2026"], r["rise_utc"]) for r in ha]
ha_set = [parse(r["date_2026"], r["set_utc"]) for r in ha]
# a pass crossing midnight would be listed under its start date; check none exist
assert all(s > r for r, s in zip(ha_rise, ha_set))

t0 = iss.epoch
t1 = ts.from_datetime(ha_set[-1]) + 1 / 24

# a) SGP4 positions, our geometry and pass extraction
t = ts.tt_jd(np.arange(t0.tt, t1.tt, 10 / 86400))
el = elevation_deg(iss.at(t).frame_xyz(itrs).m.T, lat, lon)
s, e = find_passes(j2000_s(t), el, min_el)
d_geom = match(ha_rise, ha_set, to_utc(s), to_utc(e))

# b) full pipeline: Tudat propagation from the ISS state at TLE epoch (GCRS ~ J2000 to < 0.1 arcsec)
gcrs = iss.at(t0)
state0 = np.concatenate([gcrs.position.m, gcrs.velocity.m_per_s])
# ISS drag area from the TLE drag term: B = Cd A / m = 2 B* / rho0, rho0 = 0.157 kg/m^2/ER
iss_mass, iss_cd = 450000.0, 2.2
iss_area = 2 * iss.model.bstar / 0.157 * iss_mass / iss_cd
time, el_tudat, _ = propagate_elevation(None, iss_area, iss_cd, 1.2, iss_mass,
                                        t0.tt_calendar(), t1.tt_calendar(),
                                        observer_latitude_deg=lat, observer_longitude_deg=lon,
                                        step_size=10.0, initial_cartesian_state=state0)
s, e = find_passes(time, el_tudat, min_el)
d_full = match(ha_rise, ha_set, to_utc(s), to_utc(e))
days_from_epoch = np.array([(r - t0.utc_datetime()).total_seconds() / 86400 for r in ha_rise])

# ============================== 2. DVS orbit, one year, SGP4 ==============================
res = json.load(open(os.path.join(OUTPUT_DIR, "results.json")))
min_dur = res["inputs"]["min_pass_duration_s"]
a, ecc, inc = 6890e3, 0.010, np.deg2rad(52.0)
epoch = ts.utc(2028, 1, 1)


def sgp4_year(bstar):
    """Pass statistics over 2028 with SGP4 and Skyfield's own rise/set search (mean elements = Tudat initial elements)."""
    sat = Satrec()
    sat.sgp4init(WGS72, "i", 99999, epoch.ut1 - 2433281.5, bstar, 0.0, 0.0, ecc, 0.0, inc, 0.0,
                 np.sqrt(mu_earth / a ** 3) * 60, 0.0)
    dvs = EarthSatellite.from_satrec(sat, ts)
    tt, ev = dvs.find_events(station, epoch, ts.utc(2029, 1, 1), altitude_degrees=min_el)
    # keep complete rise (0) -> set (2) pairs
    pairs = [(tt[i], tt[i + 2]) for i in range(len(ev) - 2) if ev[i] == 0 and ev[i + 2] == 2]
    dur = np.array([(b.tt - r.tt) * 86400 for r, b in pairs])
    rise_day = np.array([int(r.tt - epoch.tt) for r, _ in pairs])
    keep = dur >= min_dur
    dur, rise_day = dur[keep], rise_day[keep]
    contact = np.bincount(rise_day, weights=dur, minlength=366)[:366]
    alt_end = wgs84.height_of(dvs.at(ts.tt_jd(epoch.tt + 366 - np.arange(0, 0.07, 0.001)))).km
    return {"n_passes": len(dur), "passes_per_day": len(dur) / 366, "mean_s": dur.mean(), "std_s": dur.std(ddof=1),
            "max_s": dur.max(), "contact_s_per_day": contact.mean(), "contact_s_per_day_std": contact.std(ddof=1),
            "alt_end_min_km": alt_end.min(), "alt_end_max_km": alt_end.max()}, dur


sgp4_nodrag, dur = sgp4_year(0.0)
# drag bracket: B* from B = Cd A / m of DVS, with SGP4's fixed density profile (rho0 = 0.157 kg/m^2/ER)
sgp4_drag, _ = sgp4_year(0.157 * 2.2 * 0.02725090 / 2.2 / 2)

# ============================== 3. Analytical maximum duration ==============================
def t_max(h, eps_deg=min_el, r_e=6378.137e3):
    """SMAD: longest pass (overhead) for a circular orbit at altitude h, non-rotating Earth."""
    eps = np.deg2rad(eps_deg)
    eta = np.arcsin(r_e * np.cos(eps) / (r_e + h))
    lam = np.pi / 2 - eps - eta
    period = 2 * np.pi * np.sqrt((r_e + h) ** 3 / mu_earth)
    return period * lam / np.pi

sim = res["sim"]
# Near the northern turning point (station latitude ~ inclination) the track runs east, with the Earth's rotation:
# the relative angular rate drops by a factor (1 - omega_E / n * cos i), lengthening the pass.
omega_e = 7.2921159e-5
rot = lambda h: 1 / (1 - omega_e / np.sqrt(mu_earth / (6378.137e3 + h) ** 3) * np.cos(inc))
h_lo, h_hi = sim["alt_min_km"] * 1e3, sim["alt_max_km"] * 1e3
analytic = {"t_max_at_min_alt_s": t_max(h_lo), "t_max_at_max_alt_s": t_max(h_hi),
            "t_max_at_max_alt_rotating_s": t_max(h_hi) * rot(h_hi)}

# ============================== Output ==============================
ver = {
    "iss": {"tle_epoch_utc": t0.utc_iso(), "n_ref_passes": len(ha), "days": float(days_from_epoch[-1]),
            "area_m2": iss_area,
            "geometry_only": {k: stats(d_geom[:, i]) for i, k in enumerate(["rise", "set", "duration"])},
            "full_pipeline": {k: stats(d_full[:, i]) for i, k in enumerate(["rise", "set", "duration"])},
            "full_pipeline_first_2_days": {k: stats(d_full[days_from_epoch < 2, i]) for i, k in enumerate(["rise", "set", "duration"])}},
    "dvs_year": {"tudat": {k: res["passes"][k] for k in sgp4_nodrag if k in res["passes"]},
                 "sgp4_no_drag": sgp4_nodrag, "sgp4_drag": sgp4_drag},
    "analytic": analytic,
    "sim_max_duration_s": res["passes"]["max_s"],
}
with open(os.path.join(OUTPUT_DIR, "verification.json"), "w") as f:
    json.dump(ver, f, indent=2, default=float)
print(json.dumps(ver, indent=2, default=float))

# Figure: ISS timing errors w.r.t. Heavens-Above over the reference window
fig, axes = plt.subplots(1, 2, figsize=(6.3, 2.8), sharex=True)
for ax, col, ylabel in zip(axes, (0, 2), ("Rise time error [s]", "Duration error [s]")):
    ax.axhline(0, color=GREY, lw=0.8)
    ax.plot(days_from_epoch, d_geom[:, col], "o", color=BLUE, label="Our geometry, SGP4 orbit")
    ax.plot(days_from_epoch, d_full[:, col], "s", color=VERMILION, mfc="none", mew=1.2, label="Full pipeline (Tudat)")
    ax.set_ylabel(ylabel)
    ax.set_xlabel("Days since TLE epoch")
axes[0].legend(loc="upper left")
save(fig, os.path.join(OUTPUT_DIR, "verification_iss"))

# Figure: DVS pass duration distribution, Tudat vs SGP4
t_all, e_all, _ = np.load(os.path.join(OUTPUT_DIR, "elevation_history.npz")).values()
s, e = find_passes(t_all, e_all, min_el)
d_tudat = (e - s)[(e - s) >= min_dur]
fig, ax = plt.subplots(figsize=(6.3, 3.0))
bins = np.arange(0, 9.01, 0.25)
ax.hist(d_tudat / 60, bins=bins, density=True, color=BLUE, alpha=0.8, edgecolor="white", linewidth=0.8, label="TudatPy (this work)")
ax.hist(dur / 60, bins=bins, density=True, histtype="step", color=BLACK, lw=1.4, label="SGP4, no drag (Skyfield)")
ax.set_xlim(bins[0], bins[-1])
ax.set_xlabel("Pass duration [min]")
ax.set_ylabel("Probability density")
ax.legend(loc="upper left")
save(fig, os.path.join(OUTPUT_DIR, "verification_dvs"))
