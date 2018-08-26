import warnings
warnings.warn("Module gnome.vfs is deprecated; "
              "please import gnomevfs instead",
              DeprecationWarning)
del warnings

from gnomevfs import *
