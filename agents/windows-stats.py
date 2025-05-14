from flask import Flask, jsonify
import psutil
import gpustat
# import WinTmp
from pynvml import *
import uptime
from datetime import timedelta
from HardwareMonitor.Hardware import *  # equivalent to 'using LibreHardwareMonitor.Hardware;'

app = Flask(__name__)

OHM_hwtypes = [ 'Mainboard', 'SuperIO', 'CPU', 'RAM', 'GpuNvidia', 'GpuAti', 'TBalancer', 'Heatmaster', 'HDD' ]
OHM_sensortypes = [
 'Voltage', 'Clock', 'Temperature', 'Load', 'Fan', 'Flow', 'Control', 'Level', 'Factor', 'Power', 'Data', 'SmallData'
]

def getStats(full = False):
    global gpuAvailable
    cpu = psutil.cpu_percent(interval=1)
    mem = psutil.virtual_memory()
    (stotal, sused, sfree, spercent, sin, sout) = psutil.swap_memory()
    # cpu_temp_raw = WinTmp.CPU_Temps()

    # temp = {}
    # temp["cpu"] = cpu_temp_raw[0]
    # temp["vrm"] = cpu_temp_raw[1]
    # temp["chipset"] = cpu_temp_raw[2]
    # temp["nvme"] = cpu_temp_raw[0][3]

    temp = getTemps()

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

class UpdateVisitor(IVisitor):
    __namespace__ = "TestHardwareMonitor"  # must be unique among implementations of the IVisitor interface
    def VisitComputer(self, computer: IComputer):
        computer.Traverse(self)

    def VisitHardware(self, hardware: IHardware):
        hardware.Update()
        for subHardware in hardware.SubHardware:
            subHardware.Update()

    def VisitParameter(self, parameter: IParameter): pass

    def VisitSensor(self, sensor: ISensor): pass


def getTemps():

    computer = Computer()  # settings can not be passed as constructor argument (following below)
    computer.IsMotherboardEnabled = True
    # computer.IsControllerEnabled = True
    # computer.IsCpuEnabled = True
    # computer.IsGpuEnabled = True
    # computer.IsBatteryEnabled = True
    # computer.IsMemoryEnabled = True
    # computer.IsNetworkEnabled = True
    computer.IsStorageEnabled = True

    computer.Open()
    computer.Accept(UpdateVisitor())

    temp = {}

    for hardware in computer.Hardware:
        if "Gigabyte B650" in hardware.Name:
            for subhardware  in hardware.SubHardware:
                # print(f"\tSubhardware: {subhardware.Name}")
                for sensor in subhardware.Sensors:
                    if sensor.Name == "Temperature #1":
                        temp["sys"] = sensor.Value
                    if sensor.Name == "Temperature #2":
                        temp["chips"] = sensor.Value
                    if sensor.Name == "Temperature #3":
                        temp["cpu"] = sensor.Value
                    if sensor.Name == "Temperature #4":
                        temp["pci"] = sensor.Value
                    if sensor.Name == "Temperature #5":
                        temp["vrm"] = sensor.Value
                    if sensor.Name == "Temperature #6":
                        temp["vso"] = sensor.Value
        if "Samsung SSD 990" in hardware.Name:
            for sensor in hardware.Sensors:
                if sensor.Name == "Temperature":
                    temp["nvme"] = sensor.Value

    computer.Close()
    return temp    

@app.route("/fullstats", methods=["GET"])
def get_full_stats():
    stats = getStats(full=True)
    return jsonify(stats)

@app.route("/minstats", methods=["GET"])
def get_min_stats():
    stats = getStats(full=False)
    return jsonify(stats)

if __name__ == "__main__":
    # Initialize NVML
    global gpuAvailable
    try:
        nvmlInit()
        gpustat.GPUStatCollection.new_query()
        gpuAvailable = True
    except Exception as e:
        print(f"Error initializing NVML: {e}")
        gpuAvailable = False
    app.run(host="0.0.0.0", port=5000)
