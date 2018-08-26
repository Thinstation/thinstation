# -*- Mode: Python; py-indent-offset: 4 -*-
# pygobject - Python bindings for the GObject library
# Copyright (C) 2006  Johan Dahlin
#
#   gobject/__init__.py: initialisation file for gobject module
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

# this can go when things are a little further along

import sys

from glib import spawn_async, idle_add, timeout_add, timeout_add_seconds, \
     io_add_watch, source_remove, child_watch_add, markup_escape_text, \
     get_current_time, filename_display_name, filename_display_basename, \
     filename_from_utf8, get_application_name, set_application_name, \
     get_prgname, set_prgname, main_depth, Pid, GError, glib_version, \
     MainLoop, MainContext, main_context_default, IOChannel, Source, Idle, \
     Timeout, PollFD, OptionGroup, OptionContext, option, uri_list_extract_uris
from glib import SPAWN_LEAVE_DESCRIPTORS_OPEN, SPAWN_DO_NOT_REAP_CHILD, \
     SPAWN_SEARCH_PATH, SPAWN_STDOUT_TO_DEV_NULL, SPAWN_STDERR_TO_DEV_NULL, \
     SPAWN_CHILD_INHERITS_STDIN, SPAWN_FILE_AND_ARGV_ZERO, PRIORITY_HIGH, \
     PRIORITY_DEFAULT, PRIORITY_HIGH_IDLE, PRIORITY_DEFAULT_IDLE, \
     PRIORITY_LOW, IO_IN, IO_OUT, IO_PRI, IO_ERR, IO_HUP, IO_NVAL, \
     IO_STATUS_ERROR, IO_STATUS_NORMAL, IO_STATUS_EOF, IO_STATUS_AGAIN, \
     IO_FLAG_APPEND, IO_FLAG_NONBLOCK, IO_FLAG_IS_READABLE, \
     IO_FLAG_IS_WRITEABLE, IO_FLAG_IS_SEEKABLE, IO_FLAG_MASK, \
     IO_FLAG_GET_MASK, IO_FLAG_SET_MASK, OPTION_FLAG_HIDDEN, \
     OPTION_FLAG_IN_MAIN, OPTION_FLAG_REVERSE, OPTION_FLAG_NO_ARG, \
     OPTION_FLAG_FILENAME, OPTION_FLAG_OPTIONAL_ARG, OPTION_FLAG_NOALIAS, \
     OPTION_ERROR_UNKNOWN_OPTION, OPTION_ERROR_BAD_VALUE, \
     OPTION_ERROR_FAILED, OPTION_REMAINING, OPTION_ERROR

from gobject.constants import *
from gobject._gobject import *
_PyGObject_API = _gobject._PyGObject_API

from gobject.propertyhelper import property

sys.modules['gobject.option'] = option

class GObjectMeta(type):
    "Metaclass for automatically registering GObject classes"
    def __init__(cls, name, bases, dict_):
        type.__init__(cls, name, bases, dict_)
        cls._install_properties()
        cls._type_register(cls.__dict__)

    def _install_properties(cls):
        gproperties = getattr(cls, '__gproperties__', {})

        props = []
        for name, prop in cls.__dict__.items():
            if isinstance(prop, property): # not same as the built-in
                if name in gproperties:
                    raise ValueError
                prop.name = name
                gproperties[name] = prop.get_pspec_args()
                props.append(prop)

        if not props:
            return

        cls.__gproperties__ = gproperties

        if ('do_get_property' in cls.__dict__ or
            'do_set_property' in cls.__dict__):
            for prop in props:
                if (prop.getter != prop._default_getter or
                    prop.setter != prop._default_setter):
                    raise TypeError(
                        "GObject subclass %r defines do_get/set_property"
                        " and it also uses a property which a custom setter"
                        " or getter. This is not allowed" % (
                        cls.__name__,))

        def obj_get_property(self, pspec):
            name = pspec.name.replace('-', '_')
            prop = getattr(cls, name, None)
            if prop:
                return prop.getter(self)
        cls.do_get_property = obj_get_property

        def obj_set_property(self, pspec, value):
            name = pspec.name.replace('-', '_')
            prop = getattr(cls, name, None)
            if prop:
                prop.setter(self, value)
        cls.do_set_property = obj_set_property

    def _must_register_type(cls, namespace):
        ## don't register the class if already registered
        if '__gtype__' in namespace:
            return False

        return ('__gproperties__' in namespace or
                '__gsignals__' in namespace or
                '__gtype_name__' in namespace)

    def _type_register(cls, namespace):
        if cls._must_register_type(namespace):
            type_register(cls, namespace.get('__gtype_name__'))

_gobject._install_metaclass(GObjectMeta)

del _gobject
