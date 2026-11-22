
from flask import Flask, render_template, jsonify
import subprocess
import threading
import os
import csv
import shutil
import math
import xml.etree.ElementTree as ET
from datetime import datetime

app = Flask(__name__)

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

RESULTS_FILE = os.path.join(PROJECT_ROOT, "test", "results.xml")
TELEMETRY_FILE = os.path.join(
    PROJECT_ROOT, "reports", "spaceguard_telemetry.csv"
)


def get_test_results():
    result = {
        "total": 0,
        "passed": 0,
        "failed": 0,
        "skipped": 0,
        "timestamp": "No test results found",
        "available": False
    }

    if not os.path.exists(RESULTS_FILE):
        return result

    try:
        tree = ET.parse(RESULTS_FILE)
        root = tree.getroot()

        for suite in root.iter("testsuite"):
            tests = int(suite.attrib.get("tests", 0))
            errors = int(suite.attrib.get("errors", 0))
            failures = int(suite.attrib.get("failures", 0))
            skipped = int(suite.attrib.get("skipped", 0))

            result["total"] += tests
            result["failed"] += errors + failures
            result["skipped"] += skipped

        result["passed"] = (
            result["total"] - result["failed"] - result["skipped"]
        )

        timestamps = [
            suite.attrib.get("timestamp")
            for suite in root.iter("testsuite")
            if suite.attrib.get("timestamp")
        ]

        if timestamps:
            result["timestamp"] = timestamps[-1]

        result["available"] = True

    except (ET.ParseError, ValueError, OSError):
        result["timestamp"] = "Could not read test results"

    return result


def get_telemetry():
    result = {
        "available": False,
        "samples": [],
        "total_samples": 0,
        "signals": [],
        "latest": {},
        "start_time_ps": 0,
        "end_time_ps": 0,
        "message": "No simulation telemetry found"
    }

    if not os.path.exists(TELEMETRY_FILE):
        return result

    try:
        rows = []

        with open(TELEMETRY_FILE, "r", newline="") as file:
            reader = csv.DictReader(file)

            for row in reader:
                # The testbench uses a 1 ns / 1 ps timescale.
                # Its %0t output is therefore interpreted here as ps.
                sample = {
                    "time_ps": int(row["time_ns"]),
                    "clk": int(row["clk"]),
                    "rst_n": int(row["rst_n"]),
                    "processor_reset_n": int(row["processor_reset_n"]),
                    "execution_progress": int(row["execution_progress"]),
                    "watchdog_fault": int(row["watchdog_fault"]),
                    "critical_fault": int(row["critical_fault"]),
                    "recovery_active": int(row["recovery_active"]),
                    "recovery_success": int(row["recovery_success"]),
                    "recovery_failed": int(row["recovery_failed"]),
                    "recovery_attempts": int(row["recovery_attempts"])
                }

                rows.append(sample)

        if not rows:
            result["message"] = "Telemetry file contains no samples"
            return result

        samples = rows

        result.update({
            "available": True,
            "samples": samples,
            "total_samples": len(rows),
            "signals": [
                "clk",
                "rst_n",
                "processor_reset_n",
                "execution_progress",
                "watchdog_fault",
                "critical_fault",
                "recovery_active",
                "recovery_success",
                "recovery_failed",
                "recovery_attempts"
            ],
            "latest": rows[-1],
            "start_time_ps": rows[0]["time_ps"],
            "end_time_ps": rows[-1]["time_ps"],
            "message": "Recorded RTL simulation trace"
        })

    except (OSError, ValueError, KeyError, csv.Error):
        result["message"] = "Could not read simulation telemetry"

    return result


NEXT_SCENARIO = "normal"
SIMULATION_LOCK = threading.Lock()


@app.route("/api/run_simulation", methods=["POST"])
def run_simulation():
    global NEXT_SCENARIO

    with SIMULATION_LOCK:
        scenario = NEXT_SCENARIO
        NEXT_SCENARIO = (
            "recovery" if scenario == "normal" else "normal"
        )

        executable = os.path.join(
            PROJECT_ROOT,
            "test",
            "spaceguard_normal_sim"
            if scenario == "normal"
            else "spaceguard_recovery_sim"
        )

        try:
            completed = subprocess.run(
                [shutil.which("vvp"), executable],
                cwd=PROJECT_ROOT,
                capture_output=True,
                text=True,
                timeout=15
            )

            if completed.returncode != 0:
                return jsonify({
                    "success": False,
                    "error": completed.stderr or completed.stdout
                }), 500

            telemetry = get_telemetry()

            return jsonify({
                "success": telemetry["available"],
                "scenario": scenario,
                "output": completed.stdout,
                "telemetry": telemetry
            })

        except (OSError, subprocess.TimeoutExpired) as error:
            return jsonify({
                "success": False,
                "error": str(error)
            }), 500


@app.route("/")
def dashboard():
    test_results = get_test_results()
    telemetry = get_telemetry()

    return render_template(
        "index.html",
        test_results=test_results,
        telemetry=telemetry
    )


if __name__ == "__main__":
    app.run(debug=True)
