from flask import Flask, request, render_template_string, jsonify, redirect, session, send_from_directory
import subprocess
import requests
import re
import os

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET", "change_this_secret")

PASSWORD = os.environ.get("PANEL_PASSWORD", "admin")
METRICS_URL = "http://127.0.0.1:9101/deye.prom"

SCRIPTS = {
    "check": "/opt/deye/deye-check.sh",
    "start": "/opt/deye/deye-start.sh",
    "stop": "/opt/deye/deye-stop.sh",
    "restart": "/opt/deye/deye-restart.sh",
}

def parse_metric(text, name):
    match = re.search(rf"{name}\s+(-?\d+\.?\d*)", text)
    if match:
        return float(match.group(1))
    return None

def get_metrics():
    try:
        response = requests.get(METRICS_URL, timeout=2)
        data = response.text
        return {
            "soc": int(parse_metric(data, "deye_soc") or 0),
            "grid_power": int(parse_metric(data, "deye_totalgridpower") or 0),
            "load_power": int(parse_metric(data, "deye_totalconsumptionpower") or 0),
            "battery_power": int(parse_metric(data, "deye_batterypower") or 0),
        }
    except:
        return {
            "soc": None,
            "grid_power": None,
            "load_power": None,
            "battery_power": None,
        }

def require_auth():
    return session.get("auth") is True


def run_script(script_path):
    try:
        result = subprocess.run(
            ["/bin/bash", script_path],
            capture_output=True,
            text=True,
            cwd="/opt/deye",
            env=os.environ.copy(),
            timeout=180,
        )
    except subprocess.TimeoutExpired as exc:
        stdout = (exc.stdout or "").strip()
        stderr = (exc.stderr or "").strip()
        output_parts = []

        if stdout:
            output_parts.append(stdout)
        if stderr and stderr != stdout:
            output_parts.append(stderr)

        output_parts.append("[script timeout after 180 seconds]")
        return "\n".join(output_parts)

    output_parts = []
    stdout = (result.stdout or "").strip()
    stderr = (result.stderr or "").strip()

    if stdout:
        output_parts.append(stdout)
    if stderr and stderr != stdout:
        output_parts.append(stderr)

    if result.returncode != 0:
        output_parts.append(f"[exit code: {result.returncode}]")

    return "\n".join(output_parts) if output_parts else f"[exit code: {result.returncode}]"

LOGIN_HTML = """
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Deye Login</title>
<link rel="icon" href="/favicon.ico">
<style>
html { font-size: 90%; }
body {
    background: #0f1115;
    color: white;
    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
}
form {
    background: #1a1d23;
    padding: 30px;
    border-radius: 14px;
    text-align: center;
}
input {
    padding: 12px;
    font-size: 16px;
    border-radius: 8px;
    border: none;
    width: 220px;
    margin-bottom: 15px;
}
button {
    padding: 12px 20px;
    font-size: 16px;
    border-radius: 8px;
    border: none;
    background: #2ea043;
    color: white;
    cursor: pointer;
}
</style>
</head>
<body>
<form method="post">
    <h2>Deye Panel Login</h2>
    <input type="password" name="password" placeholder="Password" required>
    <br>
    <button type="submit">Login</button>
</form>
</body>
</html>
"""

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        if request.form.get("password") == PASSWORD:
            session["auth"] = True
            return redirect("/")
    return render_template_string(LOGIN_HTML)

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")

HTML = """
<!doctype html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Deye Control Panel</title>
<link rel="icon" href="/favicon.ico">
<style>
html { font-size: 90%; }

body {
    margin: 0;
    padding: 20px;
    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    background: #0f1115;
    color: #e6e6e6;
    text-align: center;
}

h1 {
    font-size: 24px;
    margin-bottom: 20px;
}

.dashboard {
    margin-bottom: 20px;
}

.battery {
    font-size: 52px;
    font-weight: 700;
    margin-bottom: 12px;
}

.battery.low { color: #cf222e; }
.battery.mid { color: #d29922; }
.battery.high { color: #2ea043; }

.metrics {
    font-size: 18px;
    line-height: 1.6;
}

.metric-value {
    font-size: 24px;
    font-weight: 600;
    margin-bottom: 10px;
}

.buttons {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
    margin-bottom: 20px;
}

button {
    padding: 14px;
    font-size: 16px;
    border-radius: 14px;
    border: none;
    cursor: pointer;
    font-weight: 600;
}

.check   { background: #3a82f7; color: white; }
.start   { background: #2ea043; color: white; }
.stop    { background: #cf222e; color: white; }
.restart { background: #8957e5; color: white; }

.logout {
    margin-top: 12px;
    font-size: 13px;
    color: #999;
}

.result-box {
    background: #1a1d23;
    padding: 14px;
    border-radius: 12px;
    font-family: monospace;
    font-size: 13px;
    white-space: pre-wrap;
    text-align: left;
}

</style>
</head>
<body>

<h1>Deye Control Panel</h1>

<div id="dashboard" class="dashboard">Loading...</div>

<form method="post">
<div class="buttons">
    <button name="action" value="check" class="check">Check</button>
    <button name="action" value="start" class="start">Start</button>
    <button name="action" value="stop" class="stop">Stop</button>
    <button name="action" value="restart" class="restart">Restart</button>
</div>
</form>

{% if result %}
<h3>Result:</h3>
<div class="result-box">{{ result }}</div>
{% endif %}

<div class="logout">
    <a href="/logout">Logout</a>
</div>

<script>
function updateDashboard() {
    fetch('/metrics')
        .then(response => response.json())
        .then(data => {
            let levelClass = '';
            if (data.soc !== null) {
                if (data.soc < 30) levelClass = 'low';
                else if (data.soc < 70) levelClass = 'mid';
                else levelClass = 'high';
            }

            document.getElementById('dashboard').innerHTML = `
                <div class="battery ${levelClass}">
                    🔋 ${data.soc ?? '--'}%
                </div>
                <div class="metrics">
                    ⚡ Grid Power
                    <div class="metric-value">${data.grid_power ?? '--'} W</div>
                    🔌 Load Power
                    <div class="metric-value">${data.load_power ?? '--'} W</div>
                    🔋 Battery Power
                    <div class="metric-value">${data.battery_power ?? '--'} W</div>
                </div>
            `;
        });
}

updateDashboard();
setInterval(updateDashboard, 5000);
</script>

</body>
</html>
"""

@app.route("/", methods=["GET", "POST"])
def index():
    if not require_auth():
        return redirect("/login")
    output = None
    if request.method == "POST":
        action = request.form.get("action")
        if action in SCRIPTS:
            output = run_script(SCRIPTS[action])
    return render_template_string(HTML, result=output)

@app.route("/metrics")
def metrics():
    if not require_auth():
        return jsonify({"soc": None})
    return jsonify(get_metrics())

@app.route("/favicon.ico")
def favicon():
    return send_from_directory(
        app.root_path,
        "favicon.ico",
        mimetype="image/vnd.microsoft.icon"
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9090)
