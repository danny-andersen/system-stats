from flask import Flask, jsonify
import psutil
import gpustat
import WinTmp
from pynvml import *
import json
import os
import platform
import clr

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

    win_data = getWindowsData()

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
        "win_data": win_data,
        # "fps": None  # Placeholder if you want to add RTSS/MSI Afterburner
    }
    return jsonify(stats)

def getWindowsData():
    clr.AddReference( os.path.abspath( os.path.dirname( __file__ ) ) + R'\OpenHardwareMonitorLib.dll' )
    from OpenHardwareMonitor import Hardware
    hw = Hardware.Computer()
    hw.MainboardEnabled, hw.CPUEnabled, hw.RAMEnabled, hw.GPUEnabled, hw.HDDEnabled = True, True, True, True, True
    hw.Open()     
    out = []
    for i in hw.Hardware :
        i.Update()
        for sensor in i.Sensors : 
            thing = parse_sensor( sensor )
            if thing is not None :
                out.append( thing )
            for  j in i.SubHardware :
                j.Update()
                for subsensor in j.Sensors :
                    thing = parse_sensor( subsensor )
                    out.append( thing )
    return out

def parse_sensor( snsr ) :
    if snsr.Value is not None and snsr.SensorType == OHM_sensortypes.index( 'Temperature' ) :
        HwType = OHM_hwtypes[ snsr.Hardware.HardwareType ]
        return { "Type" : HwType, "Name" : snsr.Hardware.Name, "Sensor" : snsr.Name, "Reading" : u'%s' % snsr.Value }

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
