import json
import os

from datetime import timedelta
from flask import Flask, jsonify
from uwsgidecorators import *

import psutil
import gpustat
from pynvml import *
import uptime

app = Flask(__name__)

gpuAvailable = True

def getStats(full = False):
    # CPU Stats 
    global gpuAvailable
    cpu = psutil.cpu_percent(interval=1)
    mem = psutil.virtual_memory()
    (stotal, sused, sfree, spercent, sin, sout) = psutil.swap_memory()
    cpu_temp_raw = psutil.sensors_temperatures()
    temp = {}
    for name, entries in cpu_temp_raw.items():
        if name == "k10temp":
            temp["cpu"] = entries[0][1];
        if name == "cpu_thermal":
            temp["cpu"] = entries[0][1];
        if name == "gigabyte_wmi":
            temp["vrm"] = entries[4][1];
            temp["chipset"] = entries[1][1];
        if name == "nvme":
            temp["nvme"] = entries[0][1];
    # GPU Stats via gpustat
    gpu_data = []
    
    if gpuAvailable:
        # Only use gpustat if it is available
        try:
            stats = gpustat.GPUStatCollection.new_query()
            for gpu in stats.gpus:
                gpu_data.append({
                    "name": gpu.name,
                    "index": gpu.index,
                    "temperature_C": gpu.temperature,
                    "utilization_percent": gpu.utilization,
                    "memory_used_MB": gpu.memory_used,
                    "memory_total_MB": gpu.memory_total
                })
        except Exception as e:
            gpuAvailable = False
            print(f"Error using gpustat: {e}")

    if full:
        cpu_count = psutil.cpu_count()
        cpu_freq = psutil.cpu_freq()
        disk = psutil.disk_usage('/')
        upsecs = uptime.uptime()
        bootStr = str(uptime.boottime())
        uptimeStr = str(timedelta(seconds=upsecs))
        stats = {
            "cpu": {
                "usage_percent": cpu,
                "cpu_count" : cpu_count,
                "cpu_freq" : cpu_freq,
            },
            "temperature": temp,
            "memory": {
                "total_gb": round(mem.total / (1024 ** 3), 2),
                "used_gb": round(mem.used / (1024 ** 3), 2),
                "free_gb": round(mem.available / (1024 ** 3), 2),
                "usage_percent": mem.percent
            },
            "swap": {
                "total_gb": round(stotal / (1024 ** 3), 2),
                "used_gb": round(sused / (1024 ** 3), 2),
                "free_gb": round(sfree / (1024 ** 3), 2),
                "usage_percent": spercent
            },
            # "temps": temps,
            "disk": {
                "total_gb": round(disk.total / (1024 ** 3), 2),
                "used_gb": round(disk.used / (1024 ** 3), 2),
                "free_gb": round(disk.free / (1024 ** 3), 2),
                "usage_percent": disk.percent
            },
            "gpu": gpu_data,
            "uptime": uptimeStr,
            "boot_time": bootStr,
        }
    else:    
        stats = {
            "cpu": {
                "usage_percent": cpu,
            },
            "temperature": temp,
            "memory": {
                "usage_percent": mem.percent
            },
            "swap": {
                "usage_percent": spercent
            },
            "gpu": gpu_data,
        }
    return stats

@postfork
def setup():
    # Initialize NVML
    global gpuAvailable
    try:
        gpustat.GPUStatCollection.new_query()
        gpuAvailable = True
    except Exception as e:
        print(f"Error initializing NVML: {e}")
        gpuAvailable = False
        
@app.route("/fullstats", methods=["GET"])
def get_full_stats():
    stats = getStats(full=True)
    return jsonify(stats)

@app.route("/minstats", methods=["GET"])
def get_min_stats():
    stats = getStats(full=False)
    return jsonify(stats)
   

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
