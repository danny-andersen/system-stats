#!/usr/bin/env bash
source .venv/bin/activate
uwsgi --http 0.0.0.0:5000 --rem-header Content-type --master --workers 2 -w linux-stats:app

