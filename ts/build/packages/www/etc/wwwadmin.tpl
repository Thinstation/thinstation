service wwwadmin
{
	disable 	= no
	flags		= REUSE
	socket_type	= stream        
	wait		= no
	user		= root
	server		= /bin/httpd
	server_args	= -i -h /lib/www/html/admin
	log_type	= FILE /var/log/wwwadmin
	log_on_failure	+= USERID
	only_from	= localhost $NET_REMOTE_ACCESS_FROM
}
