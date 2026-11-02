# make build PART=<name>              export 3MF/STL, render previews, check the mesh
# make build PART=<name> TARGET=<id>  the same for another print target, into out/<id>/
# make all                            the same for every part (TARGET= works here too)
# make open PART=<name>               open the part in the OpenSCAD window
PARTS := $(sort $(patsubst %/,%,$(dir $(wildcard parts/*/*.scad))))
TARGET_ARG = $(if $(TARGET),--target $(TARGET))

.PHONY: all build open clean

all:
	uv run tools/build.py $(TARGET_ARG) $(PARTS)

build:
	@test -n "$(PART)" || { echo "usage: make build PART=<name> [TARGET=<id>]"; exit 2; }
	uv run tools/build.py $(TARGET_ARG) parts/$(PART)

# A cold-started OpenSCAD keeps the window of a file handed over by "open" hidden,
# so the first launch gets the path as an argument; a running one ignores arguments.
open:
	@test -n "$(PART)" || { echo "usage: make open PART=<name>"; exit 2; }
	@test -f parts/$(PART)/$(PART).scad || { echo "parts/$(PART)/$(PART).scad not found"; exit 2; }
	@if pgrep -xq OpenSCAD; then open -a OpenSCAD parts/$(PART)/$(PART).scad; \
	else open -a OpenSCAD --args "$(CURDIR)/parts/$(PART)/$(PART).scad"; fi
	@echo "OpenSCAD: parts/$(PART)/$(PART).scad"

clean:
	rm -rf parts/*/out
