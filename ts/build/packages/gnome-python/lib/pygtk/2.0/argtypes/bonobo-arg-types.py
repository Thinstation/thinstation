import argtypes

arg = argtypes.IntArg()
argtypes.matcher.register('CORBA_long', arg)

arg = argtypes.StringArg()
argtypes.matcher.register('CORBA_char*', arg)
argtypes.matcher.register('const-CORBA_char*', arg)

arg = argtypes.DoubleArg()
argtypes.matcher.register('CORBA_float', arg)

class CorbaEnvArg(argtypes.ArgType):
    init_exception  = '    CORBA_exception_init(&%(name)s);\n'
    check_exception = '    if (pyorbit_check_ex(&%(name)s))\n' \
                      '        return NULL;\n'
    def write_param(self, ptype, pname, pdflt, pnull, info):
        info.varlist.add('CORBA_Environment', pname)
        info.codebefore.append(self.init_exception % { 'name': pname })
        info.arglist.append('&' + pname)
        info.codeafter.append(self.check_exception % { 'name': pname })

argtypes.matcher.register('CORBA_Environment*', CorbaEnvArg())

class CorbaOrbArg(argtypes.ArgType):
    null = '    if (PyObject_TypeCheck(py_%(name)s, &PyCORBA_ORB_Type))\n' \
           '        %(name)s = ((PyCORBA_ORB *)py_%(name)s)->orb;\n' \
           '    else if (py_%(name)s != Py_None) {\n' \
           '        PyErr_SetString(PyExc_TypeError, "%(name)s must be a CORBA.ORB or None");\n' \
           '        return NULL;\n' \
           '    }\n'
    def write_param(self, ptype, pname, pdflt, pnull, info):
        if pnull:
            info.varlist.add('CORBA_ORB', pname + ' = CORBA_OBJECT_NIL')
            info.varlist.add('PyObject', '*py_' + pname)
            info.codebefore.append(self.null % { 'name': pname })
            info.arglist.append(pname)
            info.add_parselist('O', ['&py_' + pname], [pname])
        else:
            info.varlist.add('PyObject', '*' + pname)
            info.arglist.append('((PyCORBA_ORB *)%s)->orb' % pname)
            info.add_parselist('O!', ['&PyCORBA_ORB_Type', '&'+pname], [pname])
    def write_return(self, ptype, ownsreturn, info):
        info.varlist.add('CORBA_ORB', 'ret')
        if ownsreturn:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL) {\n'
                                  '        PyObject *pyret = pycorba_orb_new(ret);\n'
                                  '        CORBA_Object_release((CORBA_Object)ret, NULL);\n'
                                  '        return pyret;\n'
                                  '    }\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')
        else:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL)\n'
                                  '        return pycorba_orb_new(ret);\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')

arg = CorbaOrbArg()
argtypes.matcher.register('CORBA_ORB', arg)
argtypes.matcher.register('const-CORBA_ORB', arg)

class CorbaAnyArg(argtypes.ArgType):
    null = '    if (PyObject_TypeCheck(py_%(name)s, &PyCORBA_Any_Type))\n' \
           '        %(name)s = &((PyCORBA_Any *)py_%(name)s)->any;\n' \
           '    else if (py_%(name)s != Py_None) {\n' \
           '        PyErr_SetString(PyExc_TypeError, "%(name)s must be a CORBA.Any or None");\n' \
           '        return NULL;\n' \
           '    }\n'
    def write_param(self, ptype, pname, pdflt, pnull, info):
        if pnull:
            info.varlist.add('CORBA_any', '*' + pname + ' = NULL')
            info.varlist.add('PyObject', '*py_' + pname)
            info.codebefore.append(self.null % { 'name': pname })
            info.arglist.append(pname)
            info.add_parselist('O', ['&py_' + pname], [pname])
        else:
            info.varlist.add('PyObject', '*' + pname)
            info.arglist.append('&((PyCORBA_Any *)%s)->any' % pname)
            info.add_parselist('O!', ['&PyCORBA_Any_Type', '&'+pname], [pname])
    def write_return(self, ptype, ownsreturn, info):
        info.varlist.add('CORBA_any', '*ret')
        if ownsreturn:
            info.codeafter.append('    if (ret != NULL) {\n'
                                  '        PyObject *pyret = pycorba_any_new(ret);\n'
                                  '        CORBA_free(ret);\n'
                                  '        return pyret;\n'
                                  '    }\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')
        else:
            info.codeafter.append('    if (ret != NULL)\n'
                                  '        return pycorba_any_new(ret);\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')
arg = CorbaAnyArg()
argtypes.matcher.register('CORBA_any*', arg)
argtypes.matcher.register('const-CORBA_any*', arg)
argtypes.matcher.register('BonoboArg*', arg)
argtypes.matcher.register('const-BonoboArg*', arg)

class CorbaTypeCodeArg(argtypes.ArgType):
    null = '    if (PyObject_TypeCheck(py_%(name)s, &PyCORBA_TypeCode_Type))\n' \
           '        %(name)s = ((PyCORBA_TypeCode *)py_%(name)s)->tc;\n' \
           '    else if (py_%(name)s != Py_None) {\n' \
           '        PyErr_SetString(PyExc_TypeError, "%(name)s must be a CORBA.TypeCode or None");\n' \
           '        return NULL;\n' \
           '    }\n'
    def write_param(self, ptype, pname, pdflt, pnull, info):
        if pnull:
            info.varlist.add('CORBA_TypeCode', pname + ' = CORBA_OBJECT_NIL')
            info.varlist.add('PyObject', '*py_' + pname)
            info.codebefore.append(self.null % { 'name': pname })
            info.arglist.append(pname)
            info.add_parselist('O', ['&py_' + pname], [pname])
        else:
            info.varlist.add('PyObject', '*' + pname)
            info.arglist.append('((PyCORBA_TypeCode *)%s)->tc' % pname)
            info.add_parselist('O!', ['&PyCORBA_TypeCode_Type', '&'+pname], [pname])
    def write_return(self, ptype, ownsreturn, info):
        info.varlist.add('CORBA_TypeCode', 'ret')
        if ownsreturn:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL) {\n'
                                  '        PyObject *pyret = pycorba_typecode_new(ret);\n'
                                  '        CORBA_Object_release((CORBA_Object)ret, NULL);\n'
                                  '        return pyret;\n'
                                  '    }\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')
        else:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL)\n'
                                  '        return pycorba_typecode_new(ret);\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')

arg = CorbaTypeCodeArg()
argtypes.matcher.register('CORBA_TypeCode', arg)
argtypes.matcher.register('const-CORBA_TypeCode', arg)
argtypes.matcher.register('BonoboArgType', arg)
argtypes.matcher.register('const-BonoboArgType', arg)

class CorbaPoaArg(argtypes.ArgType):
    null = '    if (PyObject_TypeCheck(py_%(name)s, &PyPortableServer_POA_Type))\n' \
           '        %(name)s = (PortableServer_POA)((PyCORBA_Object *)py_%(name)s)->objref;\n' \
           '    else if (py_%(name)s != Py_None) {\n' \
           '        PyErr_SetString(PyExc_TypeError, "%(name)s must be a PortableServer.POA or None");\n' \
           '        return NULL;\n' \
           '    }\n'
    def write_param(self, ptype, pname, pdflt, pnull, info):
        if pnull:
            info.varlist.add('PortableServer_POA', pname+' = CORBA_OBJECT_NIL')
            info.varlist.add('PyObject', '*py_' + pname)
            info.codebefore.append(self.null % { 'name': pname })
            info.arglist.append(pname)
            info.add_parselist('O', ['&py_' + pname], [pname])
        else:
            info.varlist.add('PyObject', '*' + pname)
            info.arglist.append('(PortableServer_POA)((PyCORBA_Object *)%s)->objref' % pname)
            info.add_parselist('O!', ['&PyPortableServer_POA_Type', '&'+pname], [pname])
    def write_return(self, ptype, ownsreturn, info):
        info.varlist.add('PortableServer_POA', 'ret')
        if ownsreturn:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL) {\n'
                                  '        PyObject *pyret = pyorbit_poa_new(ret);\n'
                                  '        CORBA_Object_release((CORBA_Object)ret, NULL);\n'
                                  '        return pyret;\n'
                                  '    }\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')
        else:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL)\n'
                                  '        return pyorbit_poa_new(ret);\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')

arg = CorbaPoaArg()
argtypes.matcher.register('PortableServer_POA', arg)
argtypes.matcher.register('const-PortableServer_POA', arg)

class CorbaPoaManagerArg(argtypes.ArgType):
    null = '    if (PyObject_TypeCheck(py_%(name)s, &PyPortableServer_POAManager_Type))\n' \
           '        %(name)s = (PortableServer_POAManager)((PyCORBA_Object *)py_%(name)s)->objref;\n' \
           '    else if (py_%(name)s != Py_None) {\n' \
           '        PyErr_SetString(PyExc_TypeError, "%(name)s must be a PortableServer.POAManager or None");\n' \
           '        return NULL;\n' \
           '    }\n'
    def write_param(self, ptype, pname, pdflt, pnull, info):
        if pnull:
            info.varlist.add('PortableServer_POAManager', pname+' = CORBA_OBJECT_NIL')
            info.varlist.add('PyObject', '*py_' + pname)
            info.codebefore.append(self.null % { 'name': pname })
            info.arglist.append(pname)
            info.add_parselist('O', ['&py_' + pname], [pname])
        else:
            info.varlist.add('PyObject', '*' + pname)
            info.arglist.append('(PortableServer_POAManager)((PyCORBA_Object *)%s)->objref' % pname)
            info.add_parselist('O!', ['&PyPortableServer_POAManager_Type', '&'+pname], [pname])
    def write_return(self, ptype, ownsreturn, info):
        info.varlist.add('PortableServer_POAManager', 'ret')
        if ownsreturn:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL) {\n'
                                  '        PyObject *pyret = pyorbit_poamanager_new(ret);\n'
                                  '        CORBA_Object_release((CORBA_Object)ret, NULL);\n'
                                  '        return pyret;\n'
                                  '    }\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')
        else:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL)\n'
                                  '        return pyorbit_poamanager_new(ret);\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')

arg = CorbaPoaManagerArg()
argtypes.matcher.register('PortableServer_POAManager', arg)
argtypes.matcher.register('const-PortableServer_POAManager', arg)

class CorbaObjectArg(argtypes.ArgType):
    null = '    if (PyObject_TypeCheck(py_%(name)s, &PyCORBA_Object_Type))\n' \
           '        %(name)s = (%(type)s)((PyCORBA_Object *)py_%(name)s)->objref;\n' \
           '    else if (py_%(name)s != Py_None) {\n' \
           '        PyErr_SetString(PyExc_TypeError, "%(name)s must be a CORBA.Object or None");\n' \
           '        return NULL;\n' \
           '    }\n'
    def write_param(self, ptype, pname, pdflt, pnull, info):
        if ptype[:6] == 'const-': ptype = 'const ' + ptype[6:]
        if pnull:
            info.varlist.add(ptype, pname + ' = CORBA_OBJECT_NIL')
            info.varlist.add('PyObject', '*py_' + pname)
            info.codebefore.append(self.null % { 'name': pname,
                                                 'type': ptype })
            info.arglist.append(pname)
            info.add_parselist('O', ['&py_' + pname], [pname])
        else:
            info.varlist.add('PyObject', '*' + pname)
            info.arglist.append('(%s)((PyCORBA_Object *)%s)->objref' % (ptype, pname))
            info.add_parselist('O!', ['&PyCORBA_Object_Type', '&'+pname], [pname])
    def write_return(self, ptype, ownsreturn, info):
        info.varlist.add(ptype, 'ret')
        if ownsreturn:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL) {\n'
                                  '        PyObject *pyret = pycorba_object_new(ret);\n'
                                  '        CORBA_Object_release((CORBA_Object)ret, NULL);\n'
                                  '        return pyret;\n'
                                  '    }\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')
        else:
            info.codeafter.append('    if (ret != CORBA_OBJECT_NIL)\n'
                                  '        return pycorba_object_new(ret);\n'
                                  '    Py_INCREF(Py_None);\n'
                                  '    return Py_None;')

arg = CorbaObjectArg()
argtypes.matcher.register('CORBA_Object', arg)
argtypes.matcher.register('const-CORBA_Object', arg)

argtypes.matcher.register('Bonobo_ConfigDatabase', arg)
argtypes.matcher.register('Bonobo_Listener', arg)
argtypes.matcher.register('Bonobo_Moniker', arg)
argtypes.matcher.register('Bonobo_PropertyBag', arg)
argtypes.matcher.register('Bonobo_Stream', arg)
argtypes.matcher.register('const-Bonobo_Stream', arg)
argtypes.matcher.register('Bonobo_Unknown', arg)
argtypes.matcher.register('const-Bonobo_Unknown', arg)

argtypes.matcher.register('Bonobo_Canvas_ComponentProxy', arg)
argtypes.matcher.register('Bonobo_Control', arg)
argtypes.matcher.register('Bonobo_ControlFrame', arg)
argtypes.matcher.register('Bonobo_UIContainer', arg)
argtypes.matcher.register('Bonobo_Zoomable', arg)

arg = argtypes.IntArg()
argtypes.matcher.register('Bonobo_PropertyFlags', arg)
