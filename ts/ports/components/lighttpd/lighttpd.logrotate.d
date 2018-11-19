/var/log/lighttpd/*log {
	missingok
	copytruncate
	notifempty
	sharedscripts
	postrotate
		systemctl reload lighttpd.service || true
	endscript
}
