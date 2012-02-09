#!/usr/bin/python
#
# A simple converter to convert splashy themes to fbsplash format.
#
# Copyright (C) 2008, Michal Januszewski <spock@gentoo.org>
#
# This file is a part of the splashutils package.
#
# This file is subject to the terms and conditions of the GNU General Public
# License v2.  See the file COPYING in the main directory of this archive for
# more details.

import os, sys, shutil
import xml.etree.ElementTree as et
from PIL import Image

def usage():
	print 'splashy2fbsplash/splashutils'
	print 'Usage: %s <path/theme.xml> <fbsplash_name>' % sys.argv[0]
	print
	print 'A splashy to fbsplash theme converter.'

if len(sys.argv) < 3:
	usage();
	sys.exit(0)

try:
	f = open(sys.argv[1], 'r');
	d = et.parse(f)
except:
	print >>sys.stderr, 'Failed to open or parse %s' % sys.argv[1]
	sys.exit(1)

try:
	os.mkdir('//etc/splash/%s' % (sys.argv[2]))
	os.mkdir('//etc/splash/%s/images' % (sys.argv[2]))
except:
	print >>sys.stderr, 'Failed to create //etc/splash/%s' % sys.argv[2]
	sys.exit(1)

def getColor(el):
	return (int(el.find('color/red').text) * 0x1000000 +
			int(el.find('color/green').text) * 0x10000 +
			int(el.find('color/blue').text) * 0x100 +
			int(el.find('color/alpha').text))

def processBorder(el, x, y, w, h):
	if el.find('border/enable').text == 'yes':
		print >>out, '# Border'
		brdcol = getColor(prg.find('border'))
		print >>out, 'box silent %d %d %d %d #%08x' % (x - 1, y - 1, x + w + 1, y - 1, brdcol)
		print >>out, 'box silent %d %d %d %d #%08x' % (x - 1, y + h + 1, x + w + 1, y + h + 1, brdcol)
		print >>out, 'box silent %d %d %d %d #%08x' % (x - 1, y, x - 1, y + h, brdcol)
		print >>out, 'box silent %d %d %d %d #%08x' % (x + w + 1, y, x + w + 1, y + h, brdcol)
		print >>out

if int(d.find('background/dimension/width').text) > 0 and int(d.find('background/dimension/height').text) > 0:
	pixelcoords = True
else:
	pixelcoords = False

def getSize(size, type):
	if pixelcoords:
		return size
	else:
		return size * im.size[type] / 100

## Process the background picture.
## -------------------------------
images = {}

def appendType(list, type):
	if type == 'boot':
		list.append('bootup')
		list.append('other')
	else:
		list.append(type)
	if type == 'shutdown':
		list.append('reboot')


def processImg(type):
	i = d.find('background/%s' % type).text
	if not images.has_key(i):
		images[i] = []
	appendType(images[i], type);

processImg('boot')
processImg('shutdown')
processImg('suspend')
processImg('resume')

im = Image.open('%s/%s' % (os.path.dirname(sys.argv[1]), d.find('background/boot').text))
res = '%dx%d' % (im.size[0], im.size[1])

out = open('//etc/splash/%s/%s.cfg' % (sys.argv[2], res), 'w')

print >>out, '# Background images'
for k, v in images.iteritems():
	print >>out, '<type %s>' % ' '.join(v)
	print >>out, '    silentpic = images/%s' % k
	print >>out, '</type>'
	shutil.copy('%s/%s' % (os.path.dirname(sys.argv[1]), k),
				'//etc/splash/%s/images/%s' % (sys.argv[2], k))
print >>out, ''

## Process the progress bar.
## -------------------------
print >>out, '## Progress bar'
prg = d.find('progressbar')

forward = []
backward = []

for type in ['boot', 'shutdown', 'resume', 'suspend']:
	if prg.find('visibility/' + type).text == 'yes':
		if prg.find('direction/' + type).text == 'forward':
			appendType(forward, type)
		else:
			appendType(backward, type)

dim = prg.find('dimension')
x = getSize(int(dim.find('x').text), 0)
y = getSize(int(dim.find('y').text), 1)
w = getSize(int(dim.find('width').text), 0)
h = getSize(int(dim.find('height').text), 1)

processBorder(prg, x, y, w, h)

print >>out, '# Background'
print >>out, 'box silent %d %d %d %d #%08x' % (x, y, x + w, y + h, getColor(prg.find('background')))
print >>out, ''
print >>out, '# Progress bar(s)'

if forward:
	print >>out, '<type %s>' % (' '.join(forward))
	print >>out, '    box silent inter %d %d %d %d #%08x' % (x, y, x, y, getColor(prg))
	print >>out, '    box silent %d %d %d %d #%08x' % (x, y, x + w, y + h, getColor(prg))
	print >>out, '</type>'

if backward:
	print >>out, '<type %s>' % (' '.join(backward))
	print >>out, '    box silent inter %d %d %d %d #%8x' % (x, y, x + w, y + h, getColor(prg))
	print >>out, '    box silent %d %d %d %d #%8x' % (x, y, x, y, getColor(prg))
	print >>out, '</type>'

print >>out, ''

## Process the textbox.
## --------------------
print >>out, '## Textbox'
txt = d.find('textbox')
dim = txt.find('dimension')

x = getSize(int(dim.find('x').text), 0)
y = getSize(int(dim.find('y').text), 1)
w = getSize(int(dim.find('width').text), 0)
h = getSize(int(dim.find('height').text), 1)

processBorder(txt, x, y, w, h)

print >>out, '# Background'
print >>out, 'box silent %d %d %d %d #%08x' % (x, y, x + w, y + h, getColor(txt))
print >>out, ''
print >>out, '# Text area'
print >>out, 'text %s %s %d %d #%08x msglog' % (txt.find('text/font/file').text, txt.find('text/font/height').text,
										 x, y, getColor(txt.find('text')))
print >>out, ''
print >>out, 'log_lines = %d' % (h / (int(txt.find('text/font/height').text) * 1.3))

shutil.copy('%s/%s' % (os.path.dirname(sys.argv[1]), txt.find('text/font/file').text),
			'//etc/splash/%s/%s' % (sys.argv[2], txt.find('text/font/file').text))

out.close()
f.close()

