service wwwadmin
{
	port		= 6800
	protocol	= tcp
	type		= UNLISTED
	id		= ts-admin
	flags		= REUSE
	socket_type	= stream        
	wait		= no
	user		= root
	server		= /sbin/httpd
	server_args	= -i -h /lib/www/html/admin
	log_type	= FILE /var/log/wwwadmin
	log_on_failure	+= USERID
	only_from	= localhost $NET_REMOTE_ACCESS_FROM
	disable         = no
}
