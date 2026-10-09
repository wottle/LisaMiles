FPC     ?= fpc
FPCOPTS  = -Mtp -Cr -Co -vewn -FEbuild -FUbuild -Fubuild -Fuhost_test
SRC      = src/MILES-LOGIC.TEXT

.PHONY: all test sim lint clean
all: test sim lint

build/mileslogic.pas: $(SRC)
	@mkdir -p build
	cp $(SRC) $@

build/test_logic: build/mileslogic.pas host_test/test_logic.pas host_test/testkit.pas
	$(FPC) $(FPCOPTS) host_test/test_logic.pas

build/sim: build/mileslogic.pas host_test/sim.pas
	$(FPC) $(FPCOPTS) host_test/sim.pas

test: build/test_logic
	./build/test_logic

sim: build/sim
	./build/sim 2000

lint:
	python3 tools/test_lint.py
	python3 tools/lint_lisa_subset.py $(SRC)

clean:
	rm -rf build
