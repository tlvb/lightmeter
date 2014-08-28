lightmeter.hex: lightmeter.asm
	naken_asm -h -o $@ $<

.PHONY: install
install: lightmeter.hex
	mspdebug rf2500 'erase all'
	mspdebug rf2500 'prog $<'
	mspdebug rf2500 'verify $<'
