import numpy as np
import pandas as pd
import os
from tudatpy.dynamics import environment_setup, simulator, propagation_setup
from tudatpy.interface import spice
from tudatpy.astro import time_representation, element_conversion
from tudatpy.dynamics.propagation_setup import dependent_variable
from tudatpy.dynamics.propagation import create_dependent_variable_dictionary
from tudatpy.util import result2array

OUTPUT_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "output"))


def create_bodies(reference_area, drag_coefficient, radiation_pressure_coefficient, satellite_mass):
    spice.load_standard_kernels()

    bodies_to_create = ["Earth", "Sun", "Moon"]

    global_frame_origin = "Earth"
    global_frame_orientation = "J2000"
    body_settings = environment_setup.get_default_body_settings(bodies_to_create, global_frame_origin, global_frame_orientation)

    body_settings.add_empty_settings("DVS")
    aero_coefficient_settings = environment_setup.aerodynamic_coefficients.constant(reference_area, [drag_coefficient, 0.0, 0.0])
    body_settings.get("DVS").aerodynamic_coefficient_settings = aero_coefficient_settings

    occulting_bodies_dict = dict()
    occulting_bodies_dict["Sun"] = ["Earth"]
    vehicle_target_settings = environment_setup.radiation_pressure.cannonball_radiation_target(reference_area, radiation_pressure_coefficient, occulting_bodies_dict)
    body_settings.get("DVS").radiation_pressure_target_settings = vehicle_target_settings

    bodies = environment_setup.create_system_of_bodies(body_settings)
    bodies.get("DVS").mass = satellite_mass  # kg

    return bodies


def prop_setup(bodies):
    bodies_to_propagate = ["DVS"]
    central_bodies = ["Earth"]

    accelerations_settings_dvs = dict(
        Sun=[
            propagation_setup.acceleration.radiation_pressure(),
            propagation_setup.acceleration.point_mass_gravity()
        ],
        Earth=[
            propagation_setup.acceleration.spherical_harmonic_gravity(5, 5),
            propagation_setup.acceleration.aerodynamic()
        ],
        Moon=[
            propagation_setup.acceleration.point_mass_gravity()
        ]
    )

    acceleration_settings = {"DVS": accelerations_settings_dvs}

    acceleration_models = propagation_setup.create_acceleration_models(bodies, acceleration_settings, bodies_to_propagate, central_bodies)

    return acceleration_models


def epochs(start_date, end_date):
    simulation_start_epoch = time_representation.date_time_components_to_epoch(*start_date)
    simulation_end_epoch = time_representation.date_time_components_to_epoch(*end_date)

    return simulation_start_epoch, simulation_end_epoch


def kepl_to_cart(keplerian_parameters, gravitational_parameter):
    cartesian_state = element_conversion.keplerian_to_cartesian(keplerian_parameters, gravitational_parameter)
    return cartesian_state


def dep_variables():
    dependent_variables_to_save = [
        dependent_variable.keplerian_state("DVS", "Earth"),
        dependent_variable.latitude("DVS", "Earth"),
        dependent_variable.longitude("DVS", "Earth"),
        dependent_variable.altitude("DVS", "Earth"),
        dependent_variable.central_body_fixed_cartesian_position("DVS", "Earth")
    ]
    return dependent_variables_to_save


def integrator(simulation_end_epoch, accelerations, initial_state, simulation_start_epoch, dependent_variables_to_save, fixed_step_size=5.0):

    termination_condition = propagation_setup.propagator.time_termination(simulation_end_epoch)
    integrator_settings = propagation_setup.integrator.runge_kutta_fixed_step(fixed_step_size, coefficient_set=propagation_setup.integrator.CoefficientSets.rk_4)

    central_bodies = ['Earth']
    bodies_to_propagate = ['DVS']

    propagator_settings = propagation_setup.propagator.translational(
        central_bodies,
        accelerations,
        bodies_to_propagate,
        initial_state,
        simulation_start_epoch,
        integrator_settings,
        termination_condition,
        output_variables = dependent_variables_to_save
    )
    propagator_settings.print_settings.print_initial_and_final_conditions = True

    return propagator_settings


def sim(bodies, propagator_settings):

    dynamics_simulator = simulator.create_dynamics_simulator(bodies, propagator_settings)

    states_history = dynamics_simulator.propagation_results.state_history
    dep_vars_history = dynamics_simulator.propagation_results.dependent_variable_history

    return dynamics_simulator, states_history, dep_vars_history


def save_simulation_to_csv_pandas(filename, states_array, keplerian_state_array, latitude, longitude, altitude, sim_id, initial_keplerian_state):

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filepath = os.path.join(OUTPUT_DIR, filename)

    initial_sma = initial_keplerian_state[0]
    initial_e   = initial_keplerian_state[1]
    initial_i   = initial_keplerian_state[2]

    file_exists = os.path.isfile(filepath)
    file_not_empty = file_exists and os.path.getsize(filepath) > 0

    if file_not_empty:
        try:
            existing = pd.read_csv(filepath)

            match = existing[
                (existing["initial_sma"] == initial_sma) &
                (existing["initial_e"] == initial_e) &
                (existing["initial_i"] == initial_i)
                ]

            if not match.empty:
                print(f"[SKIP] Simulation already exists for SMA={initial_sma}, e={initial_e}, i={initial_i}")
                return

        except pd.errors.EmptyDataError:
            print("[INFO] File exists but is empty, treating as new file")
            file_not_empty = False

    df = pd.DataFrame(states_array, columns=["time","x","y","z","vx","vy","vz"])

    df_kepler = pd.DataFrame(
        keplerian_state_array,
        columns=["sma","e","i","arg_periapsis","raan","true_anomaly"]
    )

    df = pd.concat([df, df_kepler], axis=1)

    df["latitude"] = latitude
    df["longitude"] = longitude
    df["altitude"] = altitude

    df["sim_id"] = sim_id
    df["initial_sma"] = initial_sma
    df["initial_e"] = initial_e
    df["initial_i"] = initial_i

    df.to_csv(
        filepath,
        mode='a' if file_not_empty else 'w',
        header=not file_not_empty,
        index=False
    )

    print(f"[✓] Saved sim {sim_id} (SMA={initial_sma}, e={initial_e}, i={initial_i})")


def elevation_deg(sat_position_body_fixed, observer_latitude_deg, observer_longitude_deg, observer_altitude=0.0):
    """Elevation [deg] of the satellite above the local horizon of a geodetic (WGS84) observer."""
    a, e2 = 6378137.0, 6.69437999014e-3
    lat, lon = np.deg2rad(observer_latitude_deg), np.deg2rad(observer_longitude_deg)
    n = a / np.sqrt(1 - e2 * np.sin(lat) ** 2)
    up = np.array([np.cos(lat) * np.cos(lon), np.cos(lat) * np.sin(lon), np.sin(lat)])  # ellipsoid normal
    observer = np.array([(n + observer_altitude) * up[0], (n + observer_altitude) * up[1], (n * (1 - e2) + observer_altitude) * up[2]])
    rho = sat_position_body_fixed - observer
    return np.degrees(np.arcsin(rho @ up / np.linalg.norm(rho, axis=1)))


def find_passes(time, elevation, min_elevation_deg):
    """Start/end times of passes above min_elevation_deg, linearly interpolated between samples.
    Passes cut by the start or end of the simulation window are dropped."""
    above = elevation >= min_elevation_deg
    d = np.diff(above.astype(int))
    rise, sets = np.where(d == 1)[0], np.where(d == -1)[0]
    if above[0]:
        sets = sets[1:]
    if above[-1]:
        rise = rise[:-1]

    def crossing(i):
        return time[i] + (min_elevation_deg - elevation[i]) * (time[i + 1] - time[i]) / (elevation[i + 1] - elevation[i])

    return crossing(rise), crossing(sets)


def propagate_elevation(keplerian_state, reference_area, drag_coefficient, radiation_pressure_coefficient, satellite_mass, start_date, end_date,
                        observer_latitude_deg=52.0, observer_longitude_deg=4.4, step_size=10.0, chunk_days=30,
                        initial_cartesian_state=None):
    """Long propagations: runs in chunks and keeps only time, elevation and altitude, so memory stays bounded."""
    bodies = create_bodies(reference_area, drag_coefficient, radiation_pressure_coefficient, satellite_mass)
    accelerations = prop_setup(bodies)
    t0, t_end = epochs(start_date, end_date)
    if initial_cartesian_state is None:
        state = list(kepl_to_cart(keplerian_state, bodies.get('Earth').gravitational_parameter))
    else:
        state = list(initial_cartesian_state)  # J2000, Earth-centred [m, m/s]
    dep_vars = [dependent_variable.altitude("DVS", "Earth"),
                dependent_variable.central_body_fixed_cartesian_position("DVS", "Earth")]

    time, elevation, altitude = [], [], []
    while t0 < t_end - step_size:
        t1 = min(t0 + chunk_days * 86400, t_end)
        settings = integrator(t1, accelerations, state, t0, dep_vars, step_size)
        settings.print_settings.print_initial_and_final_conditions = False
        dynamics_simulator = simulator.create_dynamics_simulator(bodies, settings)
        dv = result2array(dynamics_simulator.propagation_results.dependent_variable_history)  # [t, alt, x, y, z]
        states = dynamics_simulator.propagation_results.state_history
        t_last = max(states)
        state, t0 = list(states[t_last]), t_last
        first = 1 if time else 0  # chunk start duplicates the previous chunk end
        time.append(dv[first:, 0])
        altitude.append(dv[first:, 1])
        elevation.append(elevation_deg(dv[first:, 2:5], observer_latitude_deg, observer_longitude_deg))
        del dynamics_simulator, states, dv
        print(f"propagated to {(t0 - time[0][0]) / 86400:.0f} days")

    return np.concatenate(time), np.concatenate(elevation), np.concatenate(altitude)


def run_analysis(keplerian_state, reference_area, drag_coefficient, radiation_pressure_coefficient, satellite_mass, start_date, end_date, sim_id,
                 observer_latitude_deg=52.0, observer_longitude_deg=4.4, min_elevation_deg=10.0, step_size=5.0, save_csv=True):

    bodies = create_bodies(reference_area, drag_coefficient, radiation_pressure_coefficient, satellite_mass)

    accelerations = prop_setup(bodies)

    simulation_start_epoch , simulation_end_epoch = epochs(start_date, end_date)

    mu = bodies.get('Earth').gravitational_parameter
    initial_state = list(kepl_to_cart(keplerian_state, mu))

    dependent_variables_to_save = dep_variables()

    propagator_settings = integrator(simulation_end_epoch, accelerations, initial_state, simulation_start_epoch, dependent_variables_to_save, step_size)

    dynamics_simulator, states_history, dep_vars_history = sim(bodies, propagator_settings)

    states_array = result2array(states_history) # shape: epochs x 7, [epoch time, x, y, z, u, v, w]
    dep_var_dict = create_dependent_variable_dictionary(dynamics_simulator)

    keplerian_state_array = dep_var_dict.asarray(dependent_variable.keplerian_state("DVS", "Earth"))
    latitude = dep_var_dict.asarray(dependent_variable.latitude("DVS", "Earth"))
    longitude = dep_var_dict.asarray(dependent_variable.longitude("DVS", "Earth"))
    altitude = dep_var_dict.asarray(dependent_variable.altitude("DVS", "Earth"))
    earth_fixed_cartesian_position_DVS = dep_var_dict.asarray(dependent_variable.central_body_fixed_cartesian_position("DVS", "Earth"))

    ########## VISIBILITY ########
    # observer - delft
    time = states_array[:, 0]
    elevation = elevation_deg(earth_fixed_cartesian_position_DVS, observer_latitude_deg, observer_longitude_deg)

    start_times, end_times = find_passes(time, elevation, min_elevation_deg)
    durations = end_times - start_times

    print(f"{len(durations)} passes above {min_elevation_deg} deg, mean duration {np.mean(durations):.1f} s")

    if save_csv:
        save_simulation_to_csv_pandas("ground_simulations_data.csv", states_array,  keplerian_state_array, latitude, longitude, altitude, sim_id, keplerian_state)

    return time, elevation, altitude  # epoch [s since J2000], elevation [deg], altitude [m]
