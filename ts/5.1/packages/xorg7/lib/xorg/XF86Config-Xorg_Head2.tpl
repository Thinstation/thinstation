Section "InputDevice"
    Identifier	"Keyboard1"
    Driver	"kbd"
    Option	"Protocol"	"evdev"
    Option	"Dev Name"	"*eyboard*"
    Option	"Dev Phys"	"*usb*/input?"
    Option	"AutoRepeat"	"400 30"
EndSection

Section "InputDevice"
    Identifier	"Mouse1"
    Driver	"mouse"
    Option	"Protocol"	"evdev"
    Option	"Device"	"$MOUSE_DEVICE"
    Option	"ZAxisMapping"	"4 5"
    Option	"Resolution"	"$MOUSE_RESOLUTION"
EndSection

Section "ServerLayout"
        Identifier     "S1"
        Screen      1  "Screen1"
        InputDevice    "Mouse1" "CorePointer"
        InputDevice    "Keyboard1" "CoreKeyboard"
	Option          "SingleCard"    "yes"
EndSection

