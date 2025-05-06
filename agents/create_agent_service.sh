sudo cp agent.service /etc/systemd/system/agent.service
sudo systemctl enable agent.service
sudo systemctl start agent.service
sudo systemctl status agent.service
