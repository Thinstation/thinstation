import warnings
warnings.warn("Module gnome.canvas is deprecated; "
              "please import gnomecanvas instead",
              DeprecationWarning, stacklevel=2)
del warnings

from gnomecanvas import *
