lightmeter.hex: lightmeter.asm
	naken_asm -h -o $@ $<

.PHONY: install
install: lightmeter.hex
	mspdebug rf2500 'prog $<'
