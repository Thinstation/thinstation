Section "InputDevice"
    Identifier	"Keyboard0"
    Driver	"kbd"
    Option      "Protocol"      "evdev"
    Option      "Dev Name"      "*eyboard*"
    Option      "Dev Phys"       "isa*/serio?/input?"
    Option	"AutoRepeat"	"400 30"
EndSection

Section "InputDevice"
    Identifier	"Mouse0"
    Driver	"mouse"
    Option      "Device"        "$MOUSE_DEVICE"
    Option	"Protocol"	"evdev"
    Option	"ZAxisMapping"	"4 5"
    Option	"Resolution"	"$MOUSE_RESOLUTION"
EndSection

Section "ServerLayout"
        Identifier     "S0"
        Screen      0  "Screen0" 0 0
        InputDevice    "Mouse0" "CorePointer"
        InputDevice    "Keyboard0" "CoreKeyboard"
	Option		"SingleCard"	"yes"
EndSection

