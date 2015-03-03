Section "InputDevice"
    Identifier	"Keyboard0"
    Driver	"kbd"
    Option	"AutoRepeat"	"400 30"
EndSection

Section "InputDevice"
    Identifier	"Mouse0"
    Driver	"mouse"
    Option	"Protocol"	"$MOUSE_PROTOCOL"
    Option	"Device"	"$MOUSE_DEVICE"
    Option	"ZAxisMapping"	"4 5"
    Option	"Resolution"	"$MOUSE_RESOLUTION"
EndSection

