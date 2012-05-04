# The pack_cis tool from cis-tools
# <http://git.kernel.org/?p=utils/cis-tools/cis-tools.git>.
PACK_CIS = pack_cis

CIS_SRC := $(wildcard src/*.cis)
CIS_BIN := $(notdir $(CIS_SRC))

all: $(CIS_BIN)

%.cis: src/%.cis
	$(PACK_CIS) -o $@ $<

clean:
	rm -f $(CIS_BIN)
