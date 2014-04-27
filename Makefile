
VIVADO := /work/xilinx/Vivado/2014.1/bin/vivado
XMD := /work/xilinx/SDK/2014.1/bin/xmd

all::
	@echo "make build   - build project"
	@echo "make program - download bitstream to fpga"
	@echo "make watch   - observe warnings/errors from build"
	@echo "make review  - open vivado gui to inspect build results"
	@echo "make clean   - delete build results (out directory)"

build::
	@mkdir -p out
	@$(VIVADO) -mode batch -source scripts/build.tcl -log out/log.txt -nojournal

review::
	@$(VIVADO) -mode batch -source scripts/review.tcl -nolog -nojournal

program::
	@$(XMD) -tcl scripts/program.tcl

watch::
	@mkdir -p out
	@tail --follow=name --retry ./out/log.txt | grep -e WARNING: -e ERROR:

clean::
	rm -rf out usage_statistics_webtalk.* fsm_encoding.os
