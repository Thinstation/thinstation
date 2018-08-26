# -*- Mode: Python; py-indent-offset: 4 -*-
import gobject
del gobject

# load the bonobo typelib
import ORBit
ORBit.load_typelib('Bonobo')
del ORBit

import activation

from _bonobo import *

class UnknownBaseImpl(object):
    def __init__(self):
        self.__bobj = ForeignObject(self._this())
        self.__bobj.connect("destroy", self.__destroy)
    def get_bonobo_object(self):
        return self.__bobj
    def ref(self):
        self.__bobj.ref()
    def unref(self):
        self.__bobj.unref()
    def queryInterface(self, repoid):
        return self.__bobj.query_local_interface(repoid).corba_objref()
    def __destroy(self, foreign):
        # print "Deactivating Object"
        poa = self._default_POA()
        id  = poa.servant_to_id(self)
        poa.deactivate_object(id)
        # print "Removing reference to ForeignObject"
        self.__bobj = None
        # print "Deactivating Object Done"

