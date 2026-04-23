import pandas as pd
import streamlit as st
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

st.set_page_config(page_title="Airline Ops", layout="wide")
st.title("Airline Operations Dashboard")





@st.cache_resource
def get_engine() -> Engine:
    db_url = "postgresql+psycopg2://vicmft@localhost:5432/airline_db" #put your username at the place where ther is "vicmft"
    return create_engine(db_url)

engine = get_engine()

# =========================================================
# SQL Helpers
# =========================================================
def run_select(query: str, params=None) -> pd.DataFrame:
    with engine.connect() as conn:
        return pd.read_sql(text(query), conn, params=params or {})

def run_action(query: str, params=None):
    with engine.begin() as conn:
        conn.execute(text(query), params or {})

def show_df(title: str, query: str, params=None):
    st.subheader(title)
    try:
        df = run_select(query, params)
        st.dataframe(df, use_container_width=True)
    except Exception as e:
        st.error(f"SQL Error: {e}")



# =========================================================
# Requêtes métier
# =========================================================
QUERY_UNASSIGNED_FLIGHTS = """
SELECT 
    f.flight_id,
    f.flight_number,
    f.departure_airport,
    f.arrival_airport,
    f.flight_type,
    f.distance_km,
    f.departure_runway_length_m,
    f.arrival_runway_length_m,
    f.outbound_departure_time,
    f.outbound_arrival_time,
    f.return_departure_time,
    f.return_arrival_time,
    f.status AS flight_status
FROM Flights f
LEFT JOIN FlightAirplaneAssignment faa
    ON f.flight_id = faa.flight_id
WHERE faa.flight_id IS NULL
ORDER BY f.outbound_departure_time;
"""

QUERY_TECHNICALLY_ELIGIBLE_AIRPLANES = """
SELECT
    a.airplane_id,
    a.model,
    a.total_capacity,
    a.eco_capacity,
    a.business_capacity,
    a.first_capacity,
    a.range_km,
    a.min_runway_length_m,
    c.next_check_A,
    c.next_check_B,
    c.next_check_C,
    c.next_check_D,
    c.last_flight_incident_level
FROM Airplane a
JOIN Flights f
    ON f.flight_id = :flight_id
JOIN Checks c
    ON a.airplane_id = c.airplane_id
WHERE a.range_km >= f.distance_km
  AND a.min_runway_length_m <= f.departure_runway_length_m
  AND a.min_runway_length_m <= f.arrival_runway_length_m
  AND (c.next_check_A IS NULL OR c.next_check_A > DATE(f.outbound_departure_time))
  AND (c.next_check_B IS NULL OR c.next_check_B > DATE(f.outbound_departure_time))
  AND (c.next_check_C IS NULL OR c.next_check_C > DATE(f.outbound_departure_time))
  AND (c.next_check_D IS NULL OR c.next_check_D > DATE(f.outbound_departure_time))
  AND c.last_flight_incident_level IN ('none', 'light')
ORDER BY a.airplane_id;
"""

QUERY_SCHEDULE_ELIGIBLE_AIRPLANES = """
SELECT
    a.airplane_id,
    a.model,
    a.current_location,
    a.flight_status
FROM Airplane a
JOIN Flights f_target
    ON f_target.flight_id = :flight_id
WHERE NOT EXISTS (
    SELECT 1
    FROM FlightAirplaneAssignment faa
    JOIN Flights f_assigned
        ON faa.flight_id = f_assigned.flight_id
    WHERE faa.airplane_id = a.airplane_id
      AND faa.assignment_status IN ('planned', 'confirmed')
      AND f_assigned.outbound_departure_time < f_target.return_arrival_time
      AND f_assigned.return_arrival_time > f_target.outbound_departure_time
)
ORDER BY a.airplane_id;
"""

QUERY_CREW_ELIGIBILITY = """
SELECT c.*
FROM Crew c
JOIN Flights f ON f.flight_id = :flight_id
LEFT JOIN FlightAirplaneAssignment faa ON faa.flight_id = f.flight_id
LEFT JOIN Airplane a ON a.airplane_id = faa.airplane_id
WHERE c.role = :role
  AND c.status = 'active'
  AND c.haul_type = f.flight_type
  AND ( 
    c.airplane_model_qualification = a.model
  )
  AND NOT EXISTS (
      SELECT 1
      FROM CrewAssignment ca
      WHERE ca.crew_id = c.crew_id
        AND ca.status <> 'cancelled'
        AND ca.start_time <
            CASE
                WHEN :segment = 'outbound' THEN f.outbound_arrival_time
                WHEN :segment = 'return' THEN f.return_arrival_time
                ELSE f.return_arrival_time
            END
        AND ca.end_time >
            CASE
                WHEN :segment = 'outbound' THEN f.outbound_departure_time
                WHEN :segment = 'return' THEN f.return_departure_time
                ELSE f.outbound_departure_time
            END
  )
ORDER BY c.crew_id;
"""


INSERT_FLIGHT_AIRPLANE_ASSIGNMENT = """
INSERT INTO FlightAirplaneAssignment (
    assignment_id,
    flight_id,
    airplane_id,
    assignment_status
)
VALUES (
    :assignment_id,
    :flight_id,
    :airplane_id,
    :assignment_status
);
"""

INSERT_CREW_ASSIGNMENT = """
INSERT INTO CrewAssignment (
    assignment_id,
    crew_id,
    activity_type,
    flight_id,
    outbound_assigned,
    return_assigned,
    duty_role,
    start_time,
    end_time,
    location,
    notes,
    status
)
VALUES (
    :assignment_id,
    :crew_id,
    :activity_type,
    :flight_id,
    :outbound_assigned,
    :return_assigned,
    :duty_role,
    :start_time,
    :end_time,
    :location,
    :notes,
    :status
);
"""

QUERY_FLIGHT_TIMES = """
SELECT
    outbound_departure_time,
    outbound_arrival_time,
    return_departure_time,
    return_arrival_time
FROM Flights
WHERE flight_id = :flight_id;
"""

DELETE_FLIGHT_AIRPLANE_ASSIGNMENT = """
DELETE FROM FlightAirplaneAssignment
WHERE assignment_id = :assignment_id;
"""

DELETE_CREW_ASSIGNMENT = """
DELETE FROM CrewAssignment
WHERE assignment_id = :assignment_id;
"""

# =========================================================
# MENU SIMPLIFIÉ
# =========================================================
menu = st.sidebar.selectbox("Choisir une page", ["Dashboard", "Queries"])

# =========================================================
# DASHBOARD
# =========================================================
if menu == "Dashboard":
    st.header("Dashboard")

    c1, c2, c3, c4 = st.columns(4)
    try:
        with c1:
            n = run_select("SELECT COUNT(*) AS n FROM Airplane").iloc[0]["n"]
            st.metric("Airplane", n)
        with c2:
            n = run_select("SELECT COUNT(*) AS n FROM Flights").iloc[0]["n"]
            st.metric("Flights", n)
        with c3:
            n = run_select("SELECT COUNT(*) AS n FROM Crew").iloc[0]["n"]
            st.metric("Crew", n)
        with c4:
            n = run_select("SELECT COUNT(*) AS n FROM FlightAirplaneAssignment").iloc[0]["n"]
            st.metric("Assignments", n)
    except Exception as e:
        st.error(f"Erreur compteurs : {e}")

    st.markdown("---")

    show_df("Table Airplane", "SELECT * FROM Airplane ORDER BY airplane_id")
    show_df("Table Checks", "SELECT * FROM Checks ORDER BY airplane_id")
    show_df("Table Flights", "SELECT * FROM Flights ORDER BY flight_id")
    show_df("Table FlightAirplaneAssignment", "SELECT * FROM FlightAirplaneAssignment ORDER BY assignment_id")
    show_df("Table Crew", "SELECT * FROM Crew ORDER BY crew_id")
    show_df("Table CrewAssignment", "SELECT * FROM CrewAssignment ORDER BY assignment_id")

# =========================================================
# QUERIES
# =========================================================


elif menu == "Queries":
    st.header("Queries")

    st.markdown("### 1. Flights without assigned airplane")
    if st.button("Show flights without airplane"):
        show_df("Flights without assigned airplane", QUERY_UNASSIGNED_FLIGHTS)

    st.markdown("---")
    st.markdown("### 2. Technically eligible airplanes for a flight")
    flight_id_1 = st.number_input("Flight ID (technical)", min_value=1, step=1, key="flight_id_1")
    if st.button("Show technically compatible airplanes"):
        show_df(
            "Technically compatible airplanes",
            QUERY_TECHNICALLY_ELIGIBLE_AIRPLANES,
            {"flight_id": flight_id_1}
        )

    st.markdown("---")
    st.markdown("### 3. Airplanes available based on schedule")
    flight_id_2 = st.number_input("Flight ID (airplane schedule)", min_value=1, step=1, key="flight_id_2")
    if st.button("Show available airplanes"):
        show_df(
            "Available airplanes",
            QUERY_SCHEDULE_ELIGIBLE_AIRPLANES,
            {"flight_id": flight_id_2}
        )

    st.markdown("---")
    st.markdown("### 4. Check available crew for a flight")
    flight_id_3 = st.number_input("Flight ID (crew)", min_value=1, step=1, key="flight_id_3")
    role = st.selectbox("Role", ["Pilot", "Co-Pilot", "Cabin Manager", "Steward"])
    segment = st.selectbox("Segment", ["outbound", "return", "roundtrip"])

    if st.button("Show available crew"):
        show_df(
            "Available crew",
            QUERY_CREW_ELIGIBILITY,
            {
                "flight_id": flight_id_3,
                "role": role,
                "segment": segment
            }
        )

    st.markdown("---")
    st.markdown("## 5. Assign an airplane to a flight")

    with st.form("assign_airplane_form"):
        c1, c2, c3, c4 = st.columns(4)
        assignment_id = c1.number_input("Airplane Assignment ID", min_value=1, step=1)
        flight_id_assign = c2.number_input("Flight ID to assign", min_value=1, step=1)
        airplane_id_assign = c3.number_input("Airplane ID", min_value=1, step=1)
        assignment_status = c4.selectbox(
            "Assignment status",
            ["planned", "confirmed", "completed", "cancelled"]
        )

        submitted_airplane = st.form_submit_button("Assign airplane")

        if submitted_airplane:
            try:
                run_action(
                    INSERT_FLIGHT_AIRPLANE_ASSIGNMENT,
                    {
                        "assignment_id": assignment_id,
                        "flight_id": flight_id_assign,
                        "airplane_id": airplane_id_assign,
                        "assignment_status": assignment_status
                    }
                )
                st.success("Airplane successfully assigned to the flight.")
            except Exception as e:
                st.error(f"Airplane assignment error: {e}")

    show_df(
        "Airplane-Flight assignments",
        "SELECT * FROM FlightAirplaneAssignment ORDER BY assignment_id"
    )

    st.markdown("---")
    st.markdown("## 6. Assign an activity to a crew member")

    with st.form("assign_crew_form"):
        c1, c2, c3 = st.columns(3)

        crew_assignment_id = c1.number_input("Crew Assignment ID", min_value=1, step=1)
        crew_id_assign = c2.number_input("Crew ID", min_value=1, step=1)
        activity_type = c3.selectbox(
            "Activity type",
            ["flight", "rest", "on_call", "training", "medical", "leave", "off"]
        )

        if activity_type == "flight":
            c4, c5, c6 = st.columns(3)
            flight_id_crew_assign = c4.number_input("Flight ID", min_value=1, step=1)
            duty_role = c5.selectbox("Duty role", ["Pilot", "Co-Pilot", "Steward", "Cabin Manager"])
            status_assign = c6.selectbox("Crew assignment status", ["planned", "completed", "cancelled"])

            outbound_assigned = c4.checkbox("Assign outbound", value=True)
            return_assigned = c5.checkbox("Assign return", value=False)
            location = c6.text_input("Location", value="")
            notes = st.text_area("Notes", value="")

        else:
            c4, c5, c6 = st.columns(3)
            start_time_manual = c4.text_input("Start time", "2026-04-21 09:00:00")
            end_time_manual = c5.text_input("End time", "2026-04-21 17:00:00")
            status_assign = c6.selectbox("Activity status", ["planned", "completed", "cancelled"])

            location = c4.text_input("Location", value="")
            notes = st.text_area("Notes", value="")

        submitted_crew = st.form_submit_button("Assign activity")

        if submitted_crew:
            try:
                if activity_type == "flight":
                    flight_times = run_select(
                        QUERY_FLIGHT_TIMES,
                        {"flight_id": flight_id_crew_assign}
                    )

                    if flight_times.empty:
                        st.error("The given flight_id does not exist.")
                    else:
                        row = flight_times.iloc[0]

                        if outbound_assigned and return_assigned:
                            start_time = row["outbound_departure_time"]
                            end_time = row["return_arrival_time"]
                        elif outbound_assigned:
                            start_time = row["outbound_departure_time"]
                            end_time = row["outbound_arrival_time"]
                        elif return_assigned:
                            start_time = row["return_departure_time"]
                            end_time = row["return_arrival_time"]
                        else:
                            st.error("You must select at least outbound or return for a flight activity.")
                            st.stop()

                        run_action(
                            INSERT_CREW_ASSIGNMENT,
                            {
                                "assignment_id": crew_assignment_id,
                                "crew_id": crew_id_assign,
                                "activity_type": activity_type,
                                "flight_id": flight_id_crew_assign,
                                "outbound_assigned": outbound_assigned,
                                "return_assigned": return_assigned,
                                "duty_role": duty_role,
                                "start_time": start_time,
                                "end_time": end_time,
                                "location": location if location.strip() else None,
                                "notes": notes if notes.strip() else None,
                                "status": status_assign
                            }
                        )
                        st.success("Crew successfully assigned to the flight.")

                else:
                    run_action(
                        INSERT_CREW_ASSIGNMENT,
                        {
                            "assignment_id": crew_assignment_id,
                            "crew_id": crew_id_assign,
                            "activity_type": activity_type,
                            "flight_id": None,
                            "outbound_assigned": False,
                            "return_assigned": False,
                            "duty_role": None,
                            "start_time": start_time_manual,
                            "end_time": end_time_manual,
                            "location": location if location.strip() else None,
                            "notes": notes if notes.strip() else None,
                            "status": status_assign
                        }
                    )
                    st.success(f"Activity '{activity_type}' successfully assigned to the crew.")

            except Exception as e:
                st.error(f"Crew assignment error: {e}")

    st.markdown("---")
    st.markdown("## 7. Delete an airplane assignment")

    with st.form("delete_airplane_assignment"):
        assignment_id_delete = st.number_input(
            "Airplane assignment ID to delete",
            min_value=1,
            step=1,
            key="delete_airplane"
        )

        submitted_delete_airplane = st.form_submit_button("Delete airplane assignment")

        if submitted_delete_airplane:
            try:
                run_action(
                    DELETE_FLIGHT_AIRPLANE_ASSIGNMENT,
                    {"assignment_id": assignment_id_delete}
                )
                st.success("Airplane assignment deleted.")
            except Exception as e:
                st.error(f"Error: {e}")

    show_df(
        "Current airplane assignments",
        "SELECT * FROM FlightAirplaneAssignment ORDER BY assignment_id"
    )

    st.markdown("---")
    st.markdown("## 8. Delete a crew assignment")

    with st.form("delete_crew_assignment"):
        assignment_id_delete_crew = st.number_input(
            "Crew assignment ID to delete",
            min_value=1,
            step=1,
            key="delete_crew"
        )

        submitted_delete_crew = st.form_submit_button("Delete crew assignment")

        if submitted_delete_crew:
            try:
                run_action(
                    DELETE_CREW_ASSIGNMENT,
                    {"assignment_id": assignment_id_delete_crew}
                )
                st.success("Crew assignment deleted.")
            except Exception as e:
                st.error(f"Error: {e}")

    show_df(
        "Current crew assignments",
        "SELECT * FROM CrewAssignment ORDER BY assignment_id"
    )