# General
UI vesamenu.c32
TIMEOUT 150
PROMPT 0
NOESCAPE 1
IMPLICIT 1
ALLOWOPTIONS 0
MENU BACKGROUND menu/error.png

# Messages
MENU AUTOBOOT	Continuing in #.


# layout
MENU WIDTH 78
MENU MARGIN 6
MENU ROWS 6
MENU VSHIFT 2
MENU TIMEOUTROW 23
MENU TABMSGROW 24
MENU CMDLINEROW 25


# Menu colors
MENU COLOR screen       *       #80ffffff #00000000 *
MENU COLOR border       *       #00000000 #00000000 none
MENU COLOR title	*       #ffffffff #00000000 *
MENU COLOR hotkey       *       #ffffffff #00000000 *
MENU COLOR cmdmark	*	#c000ffff #00000000 *
MENU COLOR cmdline	*       #c0ffffff #00000000 *
MENU COLOR sel          *       #ffffffff #00000000 none
MENU COLOR unsel        *       #50ffffff #00000000 none
MENU COLOR hotsel       *       #e0400000 #20ff8000 *
MENU COLOR help         *       #ffffffff #00000000 none
MENU COLOR timeout_msg  *       #80ffffff #00000000 std
MENU COLOR timeout      *       #c0ffffff #00000000 std
MENU COLOR scrollbar    *       #90ffffff #a0000000 std
MENU COLOR tabmsg       *       #30ffffff #00000000 std
MENU COLOR disabled     *       #60cccccc #00000000 *
