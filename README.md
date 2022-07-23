![alt text][logo]

# Cybionet - Ugly Codes Division

## SUMMARY

Easy installation script of Zabbix Agent service.

You can choose between different options, such as:
- the Zabbix Agent version supported by your distribution.
- the source repository of the package (Zabbix or the distribution).

Works on Ubuntu, Debian and Rasbpian.


## REQUIRED

The `vx_zbxagent.sh` application does not require any additional packages to work.


## INSTALLATION

1. Download files from this repository directly with git or via https.
	```bash
	wget -o svc_zabbixagent.zip https://github.com/cybiohub/svc_zabbixagent/archive/refs/heads/main.zip
	```

2. Unzip the zip file.
	```bash
	unzip svc_zabbixagent.zip
	```

3. Make changes to the installation script to configure it to match your environment.
	
	You can customize the following settings: 

	- Choose between Zabbix repository version or distribution version. By default, this is the Zabbix repository version.
	- The version of Zabbix Agent you want to install.
	- Directory location for additional scripts. By default in `/opt/zabbix`.

4. Once completed, set the `Configured` parameter to `true`.

5. Adjust permissions.
	```bash
	chmod 500 vx_zbxagent.sh
	```

6. Run the script.
	```bash
	./vx_zbxagent.sh
	```

7. Configure Zabbix Agent service.
	```bash
	vim /etc/zabbix/zabbix_agentd.conf
	```
	```
	# TLS PSK Identity for your Zabbix Agent.
	TLSPSKIdentity=YOURZABBIXAGENT
	
	# IP address of the Zabbix server(s) authorized (passive).
	Server=W.X.Y.Z
	
	# Name identifying the Zabbix Proxy to the Zabbix server.
	Hostname=YOURZABBIXAGENT
	```

8. Activate and start the service.
	```bash
	systemctl enable zabbix-agent
	systemctl start zabbix-agent
	systemctl status zabbix-agent
	```
9. Voilà! Enjoy!
---
[logo]: ./md/logo.png "Cybionet"
