#! /bin/bash
#set -x
# ****************************************************************************
# *
# * Author:	   	(c) 2004-2022  Cybionet - Ugly Codes Division
# *
# * File:       	zbxagentchecker.sh
# * Version:    	0.0.17
# *
# * Description:    	This script checks if the zabbix_agent service is functional.
# *             	Otherwise, it sends an alert in the desired format.
# *
# * Creation: August 29, 2007
# * Change:   August 27, 2022
# *
# ****************************************************************************
# *
# * Add the following value to the crontab.
# *
# * vim /etc/cron.d/zbxagentchecker
# *
# * # Zabbix Agent Service
#   */10 * * * * root /opt/zabbix/zbxagentchecker.sh >/dev/null 2>&1
# *
# *
# * Note:
# *
# * Required to use email.
# *   dpkg-reconfigure exim4-config
# *
# *   apt-get install bsd-mailx
# *
# * Required if you want to use SMS.
# *   apt-get install smsclient
# *
# ****************************************************************************


# ############################################################
# ## CONSTANTES

# ## Configuring email sending.
#TO='alerts@example.com'
#TO='alerts@example.com,alerts2@example.com'
readonly TO='alerte@example.com'

# ## Configuring the sending of SMS (Necessity that the QPage software is functional).
readonly PAGER='8886664444'

# ## Configuration of the location of the logs (Do not put the trailing slash).
readonly LOG='/var/log/zabbix'

# ## Log name.
readonly LOGNAME='zbxagentd_check.log'

# ## Location of the zabbix_agent.conf configuration file.
#readonly CONF='/etc/zabbix/zabbix_agent.conf'

# ## Remote host for connectivity check.
readonly REMOTE='8.8.8.8'


# ############################################################
# ## VARIABLES

DATE=$(date +%Y-%m-%d%n%H:%M:%S%n)


# ############################################################
# ## LANGUAGE

# ## Subject of the message.
  SUBJECT="Zabbix - Alerte du service Agent Zabbix ${HOSTNAME}"

# ## Error messages.
  #MESSAGE1="L'Agent Zabbix de ${HOSTNAME} ne repond plus."
  MESSAGE2="Redemarrage du service zabbix_agent sur ${HOSTNAME}"
  MESSAGE3="Le service Agent Zabbix sur ${HOSTNAME} ne repond plus."
  MESSAGE4="Le serveur Agent Zabbix de ${HOSTNAME} a un probleme de configuration."
  #MESSAGE5="Trouble de connectivite (interne) sur ${HOSTNAME}."
  MESSAGE6="Trouble de connectivite (externe) sur ${HOSTNAME}."
  MESSAGE7="Erreur critique sur l'Agent Zabbix. Une intervention est nécessaire"
  MESSAGE8="Le service agent Zabbix sur ${HOSTNAME} est défunts."
  MESSAGE9="Le service agent Zabbix sur ${HOSTNAME} a démarré correctement."


# ############################################################
# ## FUNCTIONS

# #################################################################
# Function Declaration (Do not change anything under this section).
# #################################################################


# ############################################################
# ## MEDIA (Email, SMS, LOG)

email() {
 # ## Building a message to send under Ubuntu / Debian.
 echo -e "${HOSTNAME}: ${MESSAGE} \n\n${DATE}\n" > agentd_check.err

 # ## Sends email via Ubuntu / Debian.
#cat agentd_check.err | /usr/bin/mail -s "${SUBJECT}" "${TO}"
 /usr/bin/mail -s "${SUBJECT}" "${TO}" < agentd_check.err
 

 # ## Delete the temporary sending file.
 rm agentd_check.err
}

sms() {
 # ## Sends an SMS message.
 sms_client "${PAGER}" "${MESSAGE}"
}

log() {
 # ## Creating the location for the log if it does not exist.
 if [ ! -d "${LOG}" ]; then
   mkdir "${LOG}"
   chown "${LOG}" zabbix:zabbix
   chmod 664 "${LOG}"
 fi

 # ## Writing to a log file.
 echo "${DATE} ${MESSAGE}" >> "${LOG}/${LOGNAME}"
}

checkProcess() {
 # ## Verify if the zabbix_agentd service is working.
 STATUS=$(pgrep -c -x 'zabbix_agentd')

 # ## Attempt to reboot before sending an alarm.
 if [ "${STATUS}" -eq 0 ]; then
   MESSAGE="${MESSAGE3}"
   actions
   reset
 fi

 if [ "${STATUS}" -eq 0 ]; then
   MESSAGE="${MESSAGE7}"
   actions
 fi
}

defunctProcess() {
 # ## Verify if the zabbix_agentd service is not defunct.
 P_ITEM0=$(pgrep -c 'zabbix_agentd <defunct>')
 declare -i P_ITEM0

 # ## One child process died.
 #declare -i P_ITEM1=$(cat $LOG/zabbix_agentd.log | grep -c -i 'One child process died')

 #P_STATUS=$(($P_ITEM0+$P_ITEM1))
 P_STATUS=$((P_ITEM0))
 MESSAGE="${MESSAGE8}"

 # ## Attempt to reboot before sending an alarm.
 if [ "${P_STATUS}" -ne 0 ]; then
   actions
   reset
 fi

 if [ "${P_STATUS}" -ne 0 ]; then
   actions
 fi
}

checkConnectivity() {
 # ## Checks connectivity with remote host.
 if ! ping -c 1 "${REMOTE}" &> /dev/null 2>&1 ; then
   MESSAGE="${MESSAGE6}"
   actions
 fi
}

system() {
# ## BUG: SI IL Y A UNE ERREUR DANS LE LOG CETTE CETTE SECTION RESTE TOUJOURS ACTIVE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 # ## Can't find shared memory for database cache.
 S_ITEM0=$(<"${LOG}/zabbix_agentd.log" grep -c -i 'Listener failed with error')
 declare -i S_ITEM0

 # ## Listener failed with error.
 S_ITEM1=$(grep -c -i 'Listener failed with error' < /var/log/zabbix/zabbix_agentd.log)
 declare -i S_ITEM1

 S_STATUS=$((S_ITEM0+S_ITEM1))
 MESSAGE="${MESSAGE4}"

 # ## Zabbix service configuration problem.
 if [ "${S_STATUS}" -eq 0 ]; then
   actions
 fi
}

actions() {
 # ## Uncomment the actions you want (log, email, sms).
 log
 email
 #sms
}

reset() {
 # ## Resetting the zabbix_agentd service.
 systemctl stop zabbix-agent.service
 if [ -f '/var/run/zabbix/zabbix_agentd.pid' ]; then
   rm /var/run/zabbix/zabbix_agentd.pid
 fi
 systemctl start zabbix-agent.service

 # ## Added an entry in the log.
 MESSAGE="${MESSAGE2}"
 actions

 # ## Recheck the status of the zabbix_agentd service.
 STATUS=$(pgrep -c -x 'zabbix_agentd')

 # ## Attempt to reboot before sending final alarm.
 if [ "${STATUS}" -eq 0 ]; then
   MESSAGE="${MESSAGE7}"
   actions
 else
   MESSAGE="${MESSAGE9}"
   actions
 fi
}


# ############################################################
# ## EXECUTION

# ## Check the Zabbix service.
checkProcess

# ## Additional verification for Zabbix service.
defunctProcess

# ## Check connectivity (Google by default).
checkConnectivity

# ## Experimental.
# system

# ## Exit.
exit 0

# ## END
