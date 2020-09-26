#! /bin/bash
#set -x
# ****************************************************************************
# *
# * Creation:           (c) 2004-2020  Cybionet - Ugly Code Division
# *
# * File:               vx_zbxagent.sh
# * Version:            0.1.8
# *
# * Comment:            Customization script for Zabbix Agent LTS installation.
# *
# * Date: September 04, 2017
# * Change: September 25, 2020
# *
# ****************************************************************************

#############################################################################################
# ## VARIABLE

# ## Do you want to install the distribution Zabbix (0=Self selected, 1=Distribution)
installDefault="0"

# ## Zabbix Agent version.
# ## 3.x: 3.0, 3.2, 3.4
# ## 4.x: 4.0, 4.2, 4.4
# ## 5.x: 5.0
# ## 3.0, 4.0 and 5.0 are LTS version.
zbxVers="5.0"

# ## Distribution: ubuntu, debian, raspbian.
osDist=$(lsb_release -i | awk '{print $3}')

# ## Version:
# ## Ubuntu: bionic, trusty, xenial.
# ## Debian: buster, jessie, stretch.
# ## Raspbian: buster, stretch.
osVers=$(lsb_release -c | awk '{print $2}')

# ## Communication protocol with the repository (http | https | ftp).
protocol="https"

# ## Deployment URL.
urlDeploy="hub.cybionet.online"

# ## (Without the trailing slash)
scriptLocation="/opt/zabbix"


#############################################################################################
# ## VERIFICATION

# ## Check if the script are running under root user.
if [ "${EUID}" -ne "0" ]; then
  echo -n -e "\n\n\n\e[38;5;208mWARNING:This script must be run as root.\e[0m"
  exit 0
fi

# ## Last chance. Ask before execute.
echo -n -e "\n\e[38;5;208mWARNING:\e[0m You are preparing to install the Zabbix Agent service. Press 'y' to continue, or any other key to exit: "
read ANSWER
if [[ "${ANSWER}" != "y" && "${ANSWER}" != "Y" ]]; then
  echo "Have a nice day!"
  exit 0
fi


#############################################################################################
# ## FUNCTIONS

# ## Added user specified Zabbix repository.
function zx_repo {
 if [ ! -f /etc/apt/sources.list.d/zabbix.list ]; then
   echo -e "# ## Zabbix ${zbxVers} Repository" > /etc/apt/sources.list.d/zabbix.list
   echo -e "deb http://repo.zabbix.com/zabbix/${zbxVers}/${osDist,,}/  ${osVers} main contrib non-free" >> /etc/apt/sources.list.d/zabbix.list
   echo -e "deb-src http://repo.zabbix.com/zabbix/${zbxVers}/${osDist,,}/  ${osVers} main contrib non-free" >> /etc/apt/sources.list.d/zabbix.list

   apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 082AB56BA14FE591
   apt-get update
 else
   echo -e "Source file already exist!"
 fi

 # ## Zabbix agent install.
 zx_agent
}

# ## Installing the Zabbix Agent.
function zx_agent {
 apt-get install -y zabbix-agent
}

# ## 
function zx_agent_cfg {
 if [ -f "/etc/zabbix/zabbix_agentd.conf" ]; then
   mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.ori
 fi

 wget -t 1 -T 5 ${protocol}://${urlDeploy}/configs/zabbix_agent/cfg_zbxagent.tgz -O cfg_zbxagent.tgz
 tar -xzvpf cfg_zbxagent.tgz
 cp zabbix_agentd.conf /etc/zabbix/
 rm cfg_zbxagent.tgz
 
 # ## Generate the shared key (64-byte PSK).
 openssl rand -hex 64 > /etc/zabbix/zabbix_agentd.psk
}

# ##
function zx_sensors {
 apt-get install -y smartmontools
 apt-get install -y lm-sensors
}

# ## Installing Zabbix tools.
function zx_tools {
 apt-get install -y zabbix-get
 apt-get install -y zabbix-sender
}

function zx_dir {
 if [ ! -d "${scriptLocation}" ]; then
   mkdir -p ${scriptLocation}/{externalscripts,alertscripts}
   chown -R zabbix:zabbix ${scriptLocation}/
 fi

 if [ ! -d "/var/run/zabbix/" ]; then
   mkdir -p /var/run/zabbix/
   chown -R zabbix:zabbix /var/run/zabbix/
 fi

 if [ ! -d "/var/log/zabbix/" ]; then
   mkdir -p /var/log/zabbix/
   chown -R zabbix:zabbix /var/log/zabbix/
 fi
}


#############################################################################################
# ## EXECUTION

if [ "${installDefault}" -eq "0" ]; then
  # ## Added elf selected Zabbix repository.
  zx_repo
else
  # ## Installing the Zabbix Agent.
  zx_agent
fi

# ##
zx_agent_cfg

# ## Create PSK file (only if installDefault=0).
zx_agent_tls

# ## Installing Zabbix tools.
zx_tools

# ## Installing hardware sensor.
zx_sensors

# ## Activate Zabbix Agent service.
systemctl enable zabbix-agent


# ##
echo -n -e "\n\n\n\e[38;5;208mWARNING:Please configure the file /etc/zabbix/zabbix_agentd.conf.\e[0m"

# ## Exit.
exit 0

# ## END
