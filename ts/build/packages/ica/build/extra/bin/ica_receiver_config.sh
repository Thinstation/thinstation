#! /bin/sh

. $TS_GLOBAL

ICA_ROOT=/opt/Citrix/ICAClient
ICA_STOREBROWSE=$ICA_ROOT/util/storebrowse
ICA_SELFSERVICE=$ICA_ROOT/selfservice
LOGGERTAG="ica_receiver_config.sh"

	####
	# Start of Receiver configuration
	##

	logger --stderr --tag $LOGGERTAG "ica receiver körs nu..."
	
	# Kill storebrowse and other processes that might intefear...
	killall storebrowse AuthManagerDaemon ServiceRecord selfservice
	#$ICA_STOREBROWSE -l

	# Add StoreFront stores
	let x=1
	while [ -n "`eval echo '$ICA_RECEIVER_STOREFRONT_'$x'_ADDRESS'`" ]; do
		# First add the store
		$ICA_STOREBROWSE --addstore `eval echo '$ICA_RECEIVER_STOREFRONT_'$x'_ADDRESS'`
	
		# Secondly, check if we should change the Default Gateway for the added store
		#     You can find the info if you go in to Receiver --> Preferences, the tab Accounts, press Edit and
		#     there you find the "Server URL:" and "Default Gateway:" (droplist)
		#
		#     That info should be defined as ICA_RECEIVER_STOREFRONT_0_DEFAULT_GATEWAY="'Default Gateway Name as in the droplist' 'Server URL (the one that ends with /discovery)'"
		#     e.g. in the configuration files:
		#          ICA_RECEIVER_STOREFRONT_0_DEFAULT_GATEWAY="'Internal Gateway' 'https://storefront.myinternaldomain.com/citrix/myStoreName/discovery'"
		#          (note that name and url are within single quotes (') and everything is enclosed with double quotes (")
		#
		#     If the information does display completly in the application GUI you can see the information by running
		#          /opt/Citrix/ICAClient/util/storebrowse --liststores
		#
		if [ -n "`eval echo '$ICA_RECEIVER_STOREFRONT_'$x'_DEFAULT_GATEWAY'`" ]; then
			# First, extract the value into a temporary variable
			gateway_value=`eval echo '$ICA_RECEIVER_STOREFRONT_'$x'_DEFAULT_GATEWAY'`
		
			# Now, run the full command.
			`eval echo "$ICA_STOREBROWSE --storegateway $gateway_value"`
		fi
		let x=x+1
	done


	# Check if we set a specific default StoreFront store
	if [ -n "${ICA_RECEIVER_STOREFRONT_DEFAULT}" ]; then
		$ICA_STOREBROWSE --configselfservice DefaultStore=$ICA_RECEIVER_STOREFRONT_DEFAULT
	fi


	# Check Receiver Preference for Reconnect at Logon behavior
	if is_enabled ${ICA_RECEIVER_RECONNECT_ON_LOGON}; then
		$ICA_STOREBROWSE --configselfservice ReconnectOnLogon=True
	else
		$ICA_STOREBROWSE --configselfservice ReconnectOnLogon=False
	fi


	# Check Receiver Preference for Reconnect at Launch Or Refresh behavior
	if is_enabled ${ICA_RECEIVER_RECONNECT_ON_LAUNCH_OR_REFRESH}; then
		$ICA_STOREBROWSE --configselfservice ReconnectOnLaunchOrRefresh=True
	else
		$ICA_STOREBROWSE --configselfservice ReconnectOnLaunchOrRefresh=False
	fi


	# Check Receiver Preference for Display Desktops in window/full screen mode
	if is_enabled ${ICA_RECEIVER_DISPLAY_DESKTOPS_IN_FULLSCREEN}; then
		$ICA_STOREBROWSE --configselfservice SessionWindowedMode=False
	else
		$ICA_STOREBROWSE --configselfservice SessionWindowedMode=True
	fi


	# Check Receiver Preference for SharedUserMode
	if is_enabled ${ICA_RECEIVER_SHARED_USER_MODE}; then
		$ICA_STOREBROWSE --configselfservice SharedUserMode=True
	else
		$ICA_STOREBROWSE --configselfservice SharedUserMode=False
	fi


	# Check Receiver Preference for FullscreenMode
	if is_enabled ${ICA_RECEIVER_FULLSCREEN_MODE}; then
		$ICA_STOREBROWSE --configselfservice FullscreenMode=1
	else
		$ICA_STOREBROWSE --configselfservice FullscreenMode=0
	fi


	# Check Receiver Preference for SelfSelection
	if is_enabled ${ICA_RECEIVER_SELF_SELECTION}; then
		$ICA_STOREBROWSE --configselfservice SelfSelection=True
	else
		$ICA_STOREBROWSE --configselfservice SelfSelection=False
	fi

	# Add extra storebrowse configselfservice options
	let x=1
	while [ -n "`eval echo '$ICA_RECEIVER_STOREFRONT_STOREBROWSE_CONFIGSELFSERVICE_EXTRA_'$x`" ]; do
		$ICA_STOREBROWSE --configselfservice `eval echo '$ICA_RECEIVER_STOREFRONT_STOREBROWSE_CONFIGSELFSERVICE_EXTRA_'$x`
		let x=x+1
	done

	# Check if we should autostart Citrix Receiver.
	if is_enabled ${ICA_RECEIVER_AUTOSTART} ; then
		#selfservice &
		#
		# Update, launch selfservice in the Thinstation standard "package" way instead (in case there is some significat difference)
		# Ends with the & sign in order to let this script continue processing (otherwise the script wont continue/close until the
		# user closes the Citrix Receiver application
		
		# Wait 5 seconds before we start the Citrix Receiver, otherwise I hade issues that the configuration had not applied yet.
		# sleep 5
		
		# Start the package
		exec pkg window ica_wfc &
	fi


	####
	# End of Receiver configuration
	##

	####
	# Start of Receiver clear credentials job
	##

	# See if we shall schedule a job to clear the users credentials in Citrix Receiver
	if is_enabled ${ICA_RECEIVER_CLEAR_CREDENTIALS_WHEN_SESSION_LAUNCHED} || [ -n "${ICA_RECEIVER_CLEAR_CREDENTIALS_AFTER_SESSION_ENDS}" ]; then
		# Set the default check interval to 5 minutes
		CHECK_INTERVAL=5

		# Use the specified time if we have that defined. (cast it into an integer)
		if [ -n "${ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL}" ]; then
			CHECK_INTERVAL=$ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL
		fi
		
		# See if we shall schedule a job to clear the users credentials in Citrix Receiver
		# (cast it to an integer so if it's not defined it will return 0)
		if [ $((ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL)) -gt 0 ]; then
			logger --stderr --tag $LOGGERTAG "Adding ica_receiver_clear_credentials.sh with $((ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL)) minutes interval to crontab."
			
			if ! crontab -l | grep -q 'ica_receiver_clear_credentials.sh'; then
				echo "*/$((ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL)) * * * * /bin/ica_receiver_clear_credentials.sh" >> /tmp/crontab
				crontab /tmp/crontab
			fi
		else
			logger --stderr --tag $LOGGERTAG "ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL is 0 although ICA_RECEIVER_CLEAR_CREDENTIALS_WHEN_SESSION_LAUNCHED and/or ICA_RECEIVER_CLEAR_CREDENTIALS_AFTER_SESSION_ENDS are defined. No job and will not be added to crontab!"
		fi
	else
		logger --stderr --tag $LOGGERTAG "Neither ICA_RECEIVER_CLEAR_CREDENTIALS_WHEN_SESSION_LAUNCHED or ICA_RECEIVER_CLEAR_CREDENTIALS_AFTER_SESSION_ENDS are set, no job will be added to crontab."
	fi



	####
	# Start of Receiver clear credentials job
	##



notify-send 'Configuration of Citrix Receiver completed!'
