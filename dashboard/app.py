
from flask import Flask, render_template
import os
import xml.etree.ElementTree as ET
from datetime import datetime

app = Flask(__name__)

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS_FILE = os.path.join(PROJECT_ROOT, "test", "results.xml")


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


@app.route("/")
def dashboard():
    test_results = get_test_results()
    return render_template(
        "index.html",
        test_results=test_results
    )


if __name__ == "__main__":
    app.run(debug=True)
