from HardwareMonitor.Hardware import *  # equivalent to 'using LibreHardwareMonitor.Hardware;'

class UpdateVisitor(IVisitor):
    __namespace__ = "TestHardwareMonitor"  # must be unique among implementations of the IVisitor interface
    def VisitComputer(self, computer: IComputer):
        computer.Traverse(self);

    def VisitHardware(self, hardware: IHardware):
        hardware.Update()
        for subHardware in hardware.SubHardware:
            subHardware.Update()

    def VisitParameter(self, parameter: IParameter): pass

    def VisitSensor(self, sensor: ISensor): pass


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
                    temp["system"] = sensor.Value
                if sensor.Name == "Temperature #2":
                    temp["chipset"] = sensor.Value
                if sensor.Name == "Temperature #3":
                    temp["cpu"] = sensor.Value
                if sensor.Name == "Temperature #4":
                    temp["pciex16"] = sensor.Value
                if sensor.Name == "Temperature #5":
                    temp["vrm"] = sensor.Value
                if sensor.Name == "Temperature #6":
                    temp["vsocmos"] = sensor.Value
    if "Samsung SSD 990" in hardware.Name:
        for sensor in hardware.Sensors:
            if sensor.Name == "Temperature":
                temp["nvme"] = sensor.Value

computer.Close()

print (temp)