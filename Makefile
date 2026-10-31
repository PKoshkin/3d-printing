# make build PART=<name>   export 3MF/STL, render previews, check the mesh
# make all                 the same for every part
# make open PART=<name>    open the part in the OpenSCAD window
PARTS := $(sort $(patsubst %/,%,$(dir $(wildcard parts/*/*.scad))))

.PHONY: all build open clean

all:
	uv run tools/build.py $(PARTS)

build:
	@test -n "$(PART)" || { echo "usage: make build PART=<name>"; exit 2; }
	uv run tools/build.py parts/$(PART)

open:
	@test -n "$(PART)" || { echo "usage: make open PART=<name>"; exit 2; }
	open -a OpenSCAD parts/$(PART)/$(PART).scad

clean:
	rm -rf parts/*/out
