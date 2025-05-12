.\nssm set stats-agent Application "c:\stats-agent\venv\Scripts\python.exe"
.\nssm set stats-agent AppDirectory "c:\stats-agent\"
.\nssm set stats-agent AppParameters "c:\stats-agent\windows-stats.py"
.\nssm set stats-agent AppStdout "c:\stats-agent\out_file.txt"
.\nssm set stats-agent AppStderr "c:\stats-agent\error_file.txt"

.\nssm start stats-agent
