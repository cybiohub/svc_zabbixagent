#! /bin/bash
#set -x
# ****************************************************************************
# *
# * Author:		(c) 2004-2024  Cybionet - Ugly Codes Division
# *
# * File:               vx_zbxagent.sh
# * Version:            0.1.12
# *
# * Description:	Zabbix Agent LTS installation script under Ubuntu LTS Server.
# *
# * Creation: September 04, 2017
# * Change:   July 22, 2024
# *
# ****************************************************************************


#############################################################################################
# ## CUSTOM VARIABLES

# ## Set this setting to 'true' after you finish configuring the settings for this installation script.
# ## Value: enabled (true), disabled (false).
isConfigured='false'

# ## Choose the repository from which you want to install Zabbix Agent (0=Zabbix Repo (recommended), 1=Distribution Repo).
installDefault=0

# ## Zabbix Agent version.
# ## 4.x: 4.0, 4.2, 4.5 (Obsolete)
# ## 5.x: 5.0, 5.5
# ## 6.x: 6.0, 6.5
# ## 7.x: 7.0
# ## 5.0, 6.0 and 7.0 are LTS version.
zbxVers='7.0'

# ## Location of the directory containing the scripts used for the Zabbix server (Without the trailing slash).
scriptLocation="/opt/zabbix"

# ## Installing zabbix-agent2 instead (https://www.zabbix.com/documentation/5.0/en/manual/appendix/agent_comparison).
agent2=0


#############################################################################################
# ## VARIABLES

declare -r isConfigured
declare -ir installDefault
declare -r zbxVers
declare -r scriptLocation

# ## Supported distribution: ubuntu, debian, raspbian.
osDistribution=$(lsb_release -i | awk '{print $3}')
declare -r osDistribution

# ## Version of supported distributions.
# ## Ubuntu: 20.04, 22.04, 24.04
# ## Debian: 11, 12
# ## Raspbian: 11, 12
osRelease=$(lsb_release -r | awk '{print $2}')
declare -r osRelease


#############################################################################################
# ## VERIFICATION

# ## Check if the script is configured.
if [ "${isConfigured}" == 'false' ] ; then
  echo -n -e '\e[38;5;208mWARNING: Customize the settings to match your environment. Then set the "isConfigured" variable to "true".\n\e[0m'    
  exit 0
fi

# ## Check if the script are running with sudo or under root user.
if [ "${EUID}" -ne 0 ]; then
  echo -n -e "\n\n\n\e[38;5;208mWARNING:This script must be run with sudo or as root.\e[0m"
  exit 0
fi

# ## Last chance - Ask before execution.
echo -n -e "\n\e[38;5;208mWARNING:\e[0m You are preparing to install the Zabbix Agent service. Press 'y' to continue, or any other key to exit: "
read -r ANSWER
if [ "${ANSWER,,}" != 'y' ]; then
  echo 'Have a nice day!'
  exit 0
fi

# ## Don't uses distribution repo message.
if [ ${installDefault} -eq 1 ]; then
  echo -e "Do you realy want to install the distribution Zabbix Agent (Y/N) [default=N]?"
  echo -e "If not, change \"installDefault\" parameter to '0' in this script."
  read -r INSTALL
  if [ "${INSTALL,,}" != 'n' ]; then
    echo 'Good choice!'
    exit 0
  fi
fi


#############################################################################################
# ## FUNCTIONS

# ## Added Zabbix repository.
function zxRepo {
   wget -q -O zabbix-release_${zbxVers}.deb https://repo.zabbix.com/zabbix/"${zbxVers}"/"${osDistribution,,}"/pool/main/z/zabbix-release/zabbix-release_latest+"${osDistribution,,}${osRelease}"_all.deb
   dpkg -i zabbix-release_${zbxVers}.deb

   apt-get update
}

# ## Installing the Zabbix Agent.
function zxAgent {
 if [ "${agent2}" -eq 1 ]; then
   if [[ "${zbxVers}" =~ ^5|^6|^7 ]]; then
     apt-get install -y zabbix-agent2
     systemctl enable zabbix-agent2
   else
     echo  "ERROR: Zabbix Agent 2 is not compatible with the requested Zabbix version. It must be version 5.x, 6.x or 7.x."
   fi
 else
   apt-get install -y zabbix-agent
   systemctl enable zabbix-agent
 fi
}

# ## Download optimal Zabbix Agent configuration.
function zxAgentConfig {
 if [ -f '/etc/zabbix/zabbix_agentd.conf' ]; then
   mv /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.ori
 fi

 if [ "${installDefault}" -eq 0 ]; then
   # ## Check in case the deployment of Zabbix repo did not work.
   if [ -d "/etc/zabbix/zabbix_agentd.conf.d/" ]; then
     cp configs/zabbix_agentd_notls.conf /etc/zabbix/zabbix_agentd.conf
   else
     cp configs/zabbix_agentd.conf /etc/zabbix/
   fi
 else
   cp configs/zabbix_agentd_notls.conf /etc/zabbix/zabbix_agentd.conf
 fi
}

# ## Generate the shared key (64-byte PSK).
function zxAgentTls {
 if [ "${installDefault}" -eq 0 ]; then
   echo -e 'Generation Zabbix Agent 64 bit Pre-Shared Key (PSK).'
   openssl rand -hex 64 > /etc/zabbix/zabbix_agentd.psk
 else
   echo -e 'Zabbix Agent from Ubuntu repository do not support TLS.'
 fi
}

# ## Creation of additional directories required.
function zxDir {
 # ## Creation of the location for the Zabbix agent scripts if the directory does not exist.
 if [ ! -d "${scriptLocation}" ]; then
   mkdir -p "${scriptLocation}"/{externalscripts,alertscripts}
   chown -R zabbix:zabbix "${scriptLocation}"/
 fi

 # ## Creation of the directory in run for the Zabbix agent process if it does not exist.
 if [ ! -d '/var/run/zabbix/' ]; then
   mkdir -p /var/run/zabbix/
   chown -R zabbix:zabbix /var/run/zabbix/
 fi

 # ## Creation of the log directory for the Zabbix agent if it does not exist.
 if [ ! -d '/var/log/zabbix-agent/' ]; then
   mkdir -p /var/log/zabbix/
   touch /var/log/zabbix/zabbix_agentd.log
   chown -R zabbix:zabbix /var/log/zabbix/
 fi
}


# ##############
# ## EXTRA

# ## Installing Zabbix tools.
function zx_tools {
 apt-get install -y zabbix-get
 apt-get install -y zabbix-sender
}


#############################################################################################
# ## EXECUTION

# ## Set Zabbix repository for installation.
if [ "${installDefault}" -eq 0 ]; then
 # ## Added Zabbix repository as per setting.
 zxRepo
 zxAgent
else
 # ## Installing Zabbix Agent.
 zxAgent
fi

# ## Generate the shared key (64 byte PSK).
zxAgentTls

# ## Copy of the ready-to-use simplified configuration file.
zxAgentConfig

# ## Creation of the necessary directories for Zabbix.
zxDir


# ##
echo -n -e "\n\n\n\e[38;5;208mWARNING:Please configure the file /etc/zabbix/zabbix_agentd.conf.\n\e[0m"

# ## Exit.
exit 0

# ## END
