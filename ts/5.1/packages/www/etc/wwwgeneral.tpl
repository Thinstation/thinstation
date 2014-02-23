service http
{
	flags		= REUSE
	socket_type	= stream        
	wait		= no
	user		= root
	server		= /sbin/httpd
	server_args	= -i -h /lib/www/html/general
	log_on_failure	+= USERID
        disable         = no
}
