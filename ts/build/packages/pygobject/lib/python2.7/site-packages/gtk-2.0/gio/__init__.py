# -*- Mode: Python -*-
# pygobject - Python bindings for the GObject library
# Copyright (C) 2008  Johan Dahlin
#
#   gio/__init__.py: initialisation file for gio module
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
# USA

from gobject import GObjectMeta
from _gio import *
from _gio import \
     _app_info_init, _install_app_info_meta, \
     _file_init, _install_file_meta
try:
    import unix
    unix # pyflakes
except ImportError:
    unix = None
del _gio

class GFileMeta(GObjectMeta):
    __call__ = _file_init
_install_file_meta(GFileMeta)

class GAppInfoMeta(GObjectMeta):
    __call__ = _app_info_init
_install_app_info_meta(GAppInfoMeta)
