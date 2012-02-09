service wwwgeneral
{
	disable 	= no
	flags		= REUSE
	socket_type	= stream        
	wait		= no
	user		= root
	server		= /bin/httpd
	server_args	= -i -h /lib/www/html/general
	log_on_failure	+= USERID
}
