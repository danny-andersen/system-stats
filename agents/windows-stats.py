from flask import Flask, jsonify
import psutil
import gpustat
import WinTmp
from pynvml import *
import json
import os

app = Flask(__name__)

OHM_hwtypes = [ 'Mainboard', 'SuperIO', 'CPU', 'RAM', 'GpuNvidia', 'GpuAti', 'TBalancer', 'Heatmaster', 'HDD' ]
OHM_sensortypes = [
 'Voltage', 'Clock', 'Temperature', 'Load', 'Fan', 'Flow', 'Control', 'Level', 'Factor', 'Power', 'Data', 'SmallData'
]

# Initialize NVIDIA NVML
try:
    nvmlInit()
except Exception as e:
    print(f"Failed to initialize NVML: {e}")

@app.route("/stats", methods=["GET"])
def get_stats():
    cpu = psutil.cpu_percent(interval=1)
    cpu_count = psutil.cpu_count()
    cpu_freq = psutil.cpu_freq()
    mem = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    cpu_temp = WinTmp.CPU_Temps()
    # temps = psutil.sensors_temperatures()

    # GPU Stats via gpustat
    gpu_data = []
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
        print(f"Error using gpustat: {e}")

    stats = {
        "cpu": {
            "usage_percent": cpu,
            "cpu_count" : cpu_count,
            "cpu_freq" : cpu_freq,
            "cpu_temp" : cpu_temp
        },
        "memory": {
            "total_gb": round(mem.total / (1024 ** 3), 2),
            "used_gb": round(mem.used / (1024 ** 3), 2),
            "free_gb": round(mem.available / (1024 ** 3), 2),
            "usage_percent": mem.percent
        },
        # "temps": temps,
        "disk": {
            "total_gb": round(disk.total / (1024 ** 3), 2),
            "used_gb": round(disk.used / (1024 ** 3), 2),
            "free_gb": round(disk.free / (1024 ** 3), 2),
            "usage_percent": disk.percent
        },
        "gpu": gpu_data,
    }
    return jsonify(stats)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
