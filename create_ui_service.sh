sudo cp stats_ui.service /etc/systemd/system/stats_ui.service
sudo systemctl enable stats_ui.service
sudo systemctl start stats_ui.service
sudo systemctl status stats_ui.service