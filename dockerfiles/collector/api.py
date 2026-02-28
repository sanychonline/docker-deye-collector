#!/usr/bin/env python3

import os
import subprocess
from flask import Flask, request, Response

APP_SECRET = os.environ.get("APP_SECRET")
if not APP_SECRET:
    raise RuntimeError("APP_SECRET not set")

app = Flask(__name__)

COMMANDS = {
    "start":   ["/opt/deye/deye-start.sh"],
    "stop":    ["/opt/deye/deye-stop.sh"],
    "restart": ["/opt/deye/deye-restart.sh"],
    "check":   ["/opt/deye/deye-check.sh"],
}

def run_command(cmd):
    result = subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )
    return result.stdout, result.returncode

@app.route("/api/<action>", methods=["POST"])
def handle(action):

    if request.headers.get("X-API-KEY") != APP_SECRET:
        return Response("Unauthorized\n", status=401)

    if action not in COMMANDS:
        return Response("Invalid action\n", status=400)

    output, code = run_command(COMMANDS[action])
    return Response(output, status=200 if code == 0 else 500)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9090)