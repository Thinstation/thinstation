# -*- mode: python; encoding: utf-8; -*-

from _gnomevfs import *
from _gnomevfs import _PyGnomeVFS_API


def mime_get_default_component(*args, **kwargs):
    import gnomevfsbonobo
    return gnomevfsbonobo.mime_get_default_component(*args, **kwargs)

def mime_get_short_list_components(*args, **kwargs):
    import gnomevfsbonobo
    return gnomevfsbonobo.mime_get_short_list_components(*args, **kwargs)

def mime_get_all_components(*args, **kwargs):
    import gnomevfsbonobo
    return gnomevfsbonobo.mime_get_all_components(*args, **kwargs)

