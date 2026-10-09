FPC      ?= fpc
FPCOPTS   = -Mtp -Cr -Co -vewn -FEbuild -FUbuild -Fubuild -Fuhost_test
# Lisa wants (*$U MILES/X.OBJ *) before each non-intrinsic unit in a uses list; Free Pascal does
# not, so host builds copy each portable unit with those directives removed.
STRIP     = sed -e 's/(\*\$$U [^*]*\*)//g'
PORTABLE  = src/MILES-LOGIC.TEXT src/MILES-LAYOUT.TEXT src/MILES-CTRL.TEXT
LISAONLY  = src/MILES-GLOBALS.TEXT src/MILES-DRAW.TEXT src/MILES-MAIN.TEXT

# The test and simulator programs are always rebuilt (half a second): make's one-second file-time
# granularity can otherwise skip a rebuild right after a quick edit.
.PHONY: all test sim lint clean build/test_logic build/test_ui build/sim
all: test sim lint

build/mileslogic.pas: src/MILES-LOGIC.TEXT
	@mkdir -p build
	$(STRIP) $< > $@

build/mileslayout.pas: src/MILES-LAYOUT.TEXT
	@mkdir -p build
	$(STRIP) $< > $@

build/milesctrl.pas: src/MILES-CTRL.TEXT
	@mkdir -p build
	$(STRIP) $< > $@

build/test_logic: build/mileslogic.pas host_test/test_logic.pas host_test/testkit.pas
	$(FPC) $(FPCOPTS) host_test/test_logic.pas

build/test_ui: build/mileslogic.pas build/mileslayout.pas build/milesctrl.pas host_test/test_ui.pas host_test/testkit.pas
	$(FPC) $(FPCOPTS) host_test/test_ui.pas

build/sim: build/mileslogic.pas host_test/sim.pas
	$(FPC) $(FPCOPTS) host_test/sim.pas

test: build/test_logic build/test_ui
	./build/test_logic
	./build/test_ui

sim: build/sim
	./build/sim 2000

lint:
	python3 tools/test_lint.py
	python3 tools/lint_lisa_subset.py $(PORTABLE)
	python3 tools/lint_lisa_subset.py --lisa-only $(LISAONLY)
	python3 tools/lint_lisa_subset.py --collisions $(PORTABLE) $(LISAONLY)

clean:
	rm -rf build
