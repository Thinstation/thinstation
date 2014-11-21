# General
UI vesamenu.c32
TIMEOUT 150
PROMPT 0

#NOESCAPE 0
#IMPLICIT 0
#ALLOWOPTIONS 0

# Messages
#MENU AUTOBOOT	Automatic boot in # second{,s}...
#MENU TABMSG	Press [Tab] to edit options
#MENU NOTABMSG
#MENU PASSPROMPT	Password required

# layout
MENU WIDTH 78
MENU MARGIN 6
MENU ROWS 18
MENU TIMEOUTROW 27
MENU TABMSGROW 25
MENU CMDLINEROW 22

MENU SEPARATOR
MENU SEPARATOR
MENU SEPARATOR

# Menu Colors
#MENU COLOR screen	*  #80ffffff #00000000 std
#MENU COLOR border	*  #40000000 #00000000 std
MENU COLOR title	*  #ffffffff #00000000 std
MENU COLOR unsel	0  #20ffffff #00000000 none
#MENU COLOR hotkey	*  #ffffffff #00000000 std
MENU COLOR sel		0  #ffffffff #00000000 none
#MENU COLOR hotsel	*  #e0400000 #20ff8000 all
#MENU COLOR disabled	*  #60cccccc #00000000 std
#MENU COLOR scrollbar	*  #40000000 #00000000 std
#MENU COLOR tabmsg	*  #90ffff00 #00000000 std
#MENU COLOR cmdmark	*  #c000ffff #00000000 std
#MENU COLOR cmdline	*  #c0ffffff #00000000 std
#MENU COLOR pwdborder	*  #80ffffff #20ffffff std
#MENU COLOR pwdheader	*  #80ff8080 #20ffffff std
#MENU COLOR pwdentry	*  #80ffffff #20ffffff std
#MENU COLOR timeout_msg	*  #80ffffff #00000000 std
#MENU COLOR timeout	*  #c0ffffff #00000000 std
#MENU COLOR help	*  #c0ffffff #00000000 std
#MENU COLOR msg07	*  #90ffffff #00000000 std


