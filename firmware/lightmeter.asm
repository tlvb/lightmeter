.include "msp430g2x31.inc"
; vim: set syntax=msp:

.macro red_led_on
						bis.b		#0x01, &P1OUT
.endm
.macro red_led_off
						bic.b		#0x01, &P1OUT
.endm

; usart defines {{{
SUS_TXPIN equ 0x02
SUS_TXDIR equ P1DIR
SUS_TXOUT equ P1OUT
// static softusart variables
SUS_TXB equ 0x0200
SUS_TXS equ 0x0202
SUS_TXW equ 0x0204
; }}}
; lightmeter defines {{{
c0 equ 0x0224
c1 equ 0x0226
c0l equ 0x0224
c0h equ 0x0225
c1l equ 0x0226
c1h equ 0x0227
lm_i2c_write_select equ 0x72
lm_i2c_read_select equ 0x73
lm_power_up equ 0x0380 ; command = 03, reg = 00
lm_long_integration_time equ 0x1281 ; command = 12, reg = 01
lm_adc_block_read equ 0x9c
; }}}
; division function defines {{{
NUMERATOR equ 0x0228
DIVISOR equ 0x022a
QUOTIENT equ 0x022c
QUOTIENTL equ 0x022c
QUOTIENTH equ 0x022d
; }}}
c0bl equ 0x022e
c0bh equ 0x0230
c1ml equ 0x0232
c1mh equ 0x0234
; multiplication function defines {{{
MUL0 equ 0x0236
MUL1 equ 0x0238
PROL equ 0x023a
PROH equ 0x023c
; }}}

.org 0x1000

IDSTR:
.db 0xa
.db "lightmeter"
.db 0xa
.db 0x0

; from the datasheet for tsl2561
KVALS: ; {{{
dw 0x0040
dw 0x0080
dw 0x00c0
dw 0x0100
dw 0x0138
dw 0x019a
dw 0x029a
dw 0xffff
; }}}
BVALS: ;{{{
dw 0x01f2
dw 0x0214
dw 0x023f
dw 0x0270
dw 0x016f
dw 0x00d2
dw 0x0018
dw 0x0000
; }}}
MVALS: ; {{{
dw 0x01be
dw 0x02d1
dw 0x037b
dw 0x03fe
dw 0x01fc
dw 0x00fb
dw 0x0012
dw 0x0000
; }}}

.org 0xfff2
INTERRUPT_TABLE:																; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						dw			SUS_TACCR0_CCIFG_HANDLER
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT							; set reset vector to point to the MAIN_ENTRY_POINT label
; }}}

.org 0xf800
MAIN_ENTRY_POINT:																; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						mov.w		#0x0280, sp
						mov.w		#(WDTPW|WDTHOLD), &WDTCTL

						clr.b		&DCOCTL
						mov.b		&0x10ff, &BCSCTL1
						mov.b		&0x10fe, &DCOCTL

						bis.b		#0x03, &P1DIR
						call		#i2c_setup
						call		#sus_setup
						eint
						red_led_off

						mov			#lm_power_up, r4
						call		#lightmeter_send_command

						mov			#lm_long_integration_time, r4
						call		#lightmeter_send_command

						mov.w		#IDSTR, &SUS_TXW
						call		#sus_sendstr

IDLE_LOOP_START:
						call		#lightmeter_read

						call		#sus_send_0x
						mov			&c0, &SUS_TXW
						call		#sus_send_hex_word

						call		#sus_send_space

						call		#sus_send_0x
						mov			&c1, &SUS_TXW
						call		#sus_send_hex_word

						call		#sus_send_space

						mov			&c1, &NUMERATOR
						mov			&c0, &DIVISOR
						call		#divide
						call		#sus_send_0x
						mov			&QUOTIENT, &SUS_TXW
						call		#sus_send_hex_word

						call		#sus_send_cr

						jmp			IDLE_LOOP_START
; }}}

convert:																		; {{{
; --------------------------------------------------------------------------------------------------------------------------------

						push		r4
						push		r5
						push		r6
						push		r7

						mov.b		#0x00, r4
						mov.w		&QUOTIENT, r5								; r5 is the channel ratio

cmp_loop:				cmp.w		KVALS(r4), r5								; r4 is the index of the constants
						jge			continue_cmp_loop

continue_cmp_loop:		add.w		0x0002, r4
						cmp.w		#0x0016, r4
						jlo			cmp_loop

						mov.w		BVALS(r4), &MUL0
						mov.w		c0, &MUL1
						call		#multiply
						mov.w		&PROH, &c0bh
						mov.w		&PROH, &c0bl

						mov.w		MVALS(r4), &MUL0
						mov.w		c1, &MUL1
						call		#multiply
						mov.w		&PROH, &c1mh
						mov.w		&PROL, &c1ml

						cmp.w		&c1mh, &c0bh
						; ...
; }}}

lightmeter_read:																; {{{
; --------------------------------------------------------------------------------------------------------------------------------

						call		#i2c_generate_start
						mov.b		#lm_i2c_write_select, &USISRL
						call		#i2c_transmit_byte_get_ack
						mov.b		#lm_adc_block_read, &USISRL
						call		#i2c_transmit_byte_get_ack

						call		#i2c_generate_restart

						mov.b		#lm_i2c_read_select, &USISRL
						call		#i2c_transmit_byte_get_ack
						call		#i2c_receive_byte_set_ack
						mov.b		r5, &c0l
						call		#i2c_receive_byte_set_ack
						mov.b		r5, &c0h
						call		#i2c_receive_byte_set_ack
						mov.b		r5, &c1l
						call		#i2c_receive_byte_set_nack
						mov.b		r5, &c1h
						jmp			i2c_generate_stop
; }}}
lightmeter_send_command:																			; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						call		#i2c_generate_start
						mov.b		#lm_i2c_write_select, &USISRL
						call		#i2c_transmit_byte_get_ack
						mov.b		r4, &USISRL
						call		#i2c_transmit_byte_get_ack
						swpb		r4
						mov.b		r4, &USISRL
						call		#i2c_transmit_byte_get_ack
						jmp			i2c_generate_stop
; }}}

i2c_setup:																		; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						bis.b		#USISWRST, &USICTL0							; put in reset mode
						bis.b		#(USIPE6|USIPE7|USIMST), &USICTL0			; port enable and master transmit mode
						bis.b		#USII2C, &USICTL1							; enable i2c mode
						bis.b		#(USIDIV_5|USISSEL_2|USICKPL), &USICKCTL	; clock prescaler source and polarity select
						bic.b		#USISWRST, &USICTL0
						ret
; }}}
i2c_transmit_byte_get_ack:														; {{{
;						ARG:		r4: ack aggregate so far
;						RET:		r4: r4 shifted left | last ack value
; --------------------------------------------------------------------------------------------------------------------------------
						bis.b		#USIOE, &USICTL0							; enable output
						mov.b		#0x08, &USICNT								; send 8 bits
i2c_tx_byte_wait0:		bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			i2c_tx_byte_wait0							; loop if not

						bic.b		#USIOE, &USICTL0							; disable output
						mov.b		#0x01, &USICNT								; receive one bit
i2c_tx_byte_wait1:		bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			i2c_tx_byte_wait1							; loop if not
						bis.b		#USIOE, &USICTL0							; enable output

						add.w		r4, r4										; shift r4 to left
						bis.b		&USISRL, r4

						ret
; }}}
i2c_receive_byte_set_ack:	; and i2c_receive_byte_set_nack:					; {{{
;						ARG:		- none -
;						RET:		r5: received data
; --------------------------------------------------------------------------------------------------------------------------------
						push		r6
						mov.b		#0x00, r6
						jmp			i2c_rx_byte_set_acknack
i2c_receive_byte_set_nack:
						push		r6
						mov.b		#0xff, r6
i2c_rx_byte_set_acknack:

						bic.b		#USIOE, &USICTL0							; disable output
						mov.b		#0x08, &USICNT								; receive eight bits
i2c_rx_byte_wait0:		bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			i2c_rx_byte_wait0							; loop if not
						mov.b		&USISRL, r5									; harvest received data

						bis.b		#USIOE, &USICTL0							; enable output
						mov.b		r6, &USISRL									; ack or nack bit
						mov.b		#0x01, &USICNT								; write one bit
i2c_rx_byte_wait1:		bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			i2c_rx_byte_wait1							; loop if not

						pop			r6
						ret
; }}}
i2c_generate_start:																; {{{
; generate i2c start
;
;          0
; ____.____.    .
;     .    \____. SCA
;     .    .
; ____.____.____.
;     .    .    . SCL
;          |
;
; --------------------------------------------------------------------------------------------------------------------------------
						mov.b		#0x00, &USISRL								; msb = 0
						bis.b		#(USIOE|USIGE), &USICTL0					; transparent latch (0)
						bic.b		#USIGE, &USICTL0							; disable latch
						ret
; }}}
i2c_generate_restart:																	; {{{
; generate i2c restart
;
;          0
;     .____.    .
; XXXX.    \____. SCA
;     .    .
; ____.____.____.
;     .    .    . SCL
;          |
;
; --------------------------------------------------------------------------------------------------------------------------------
						bis.b		#USIOE, &USICTL0							; output enable
						mov.b		#0xff, &USISRL								; msb = 1
						mov.b		#0x01, &USICNT								; one bit to send (0)
i2c_gen_restart_wait:	bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			i2c_gen_restart_wait						; loop if not
						mov.b		#0x00, &USISRL								; msb = 0
i2c_restartstop_end:	bis.b		#USIGE, &USICTL0							; make latch transparent (1)
						bic.b		#(USIGE|USIOE), &USICTL0					; disable output
						ret
; }}}
i2c_generate_stop:																	; {{{
; generate i2c stop
;
;     00000000001111122222
;     .    .    .____.____.
; XXXX.____.____/    .    . SCA
;     .    .    .    .
;     .    .____.____.____.
; ____.____/    .    .    . SCL
;               |
;
; --------------------------------------------------------------------------------------------------------------------------------
						bis.b		#USIOE, &USICTL0							; output enable
						mov.b		#0x00, &USISRL								; msb = 0
						mov.b		#0x01, &USICNT								; one bit to send (0)
i2c_gen_stop_wait:		bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			i2c_gen_stop_wait							; loop if not
						mov.b		#0xff, &USISRL								; msb = 1
						jmp			i2c_restartstop_end
; }}}

sus_setup:																	; {{{
; set up the serial connection ( pin as output and kick the timer into gear)
; --------------------------------------------------------------------------------------------------------------------------------
						mov.w		#0x0000, &SUS_TXS
						bis.b		#SUS_TXPIN, &SUS_TXDIR
						bis.b		#SUS_TXPIN, &SUS_TXOUT
						clr.w		&TACCR0
						clr.w		&TACCTL0
						clr.w		&TACTL
						ret
; }}}
sus_wait:																		; {{{
; wait until previous byte has finished transmitting
; --------------------------------------------------------------------------------------------------------------------------------
						tst.w		&SUS_TXS
						jnz			sus_wait
						ret
; }}}
sus_send_space:																	; {{{
; transmit a single space
; --------------------------------------------------------------------------------------------------------------------------------
						call		#sus_wait
						mov.b		#0x20, &SUS_TXB
						jmp			sus_txb
; }}}
sus_send_cr:																	; {{{
; transmit a single carriage return
; --------------------------------------------------------------------------------------------------------------------------------
						call		#sus_wait
						mov.b		#0x0a, &SUS_TXB
						jmp			sus_txb
; }}}
sus_send_0x:																	; {{{
; transmit "0x" to marshal the coming of a hex number
; --------------------------------------------------------------------------------------------------------------------------------
						call		#sus_wait
						mov.b		#0x30, &SUS_TXB
						call		#sus_txb
						call		#sus_wait
						mov.b		#0x78, &SUS_TXB
						jmp			sus_txb
; }}}
sus_send_hex_word:																; {{{
; transmit word in as ascii hex
; --------------------------------------------------------------------------------------------------------------------------------
						push		#sus_send_hex_word_work
sus_send_hex_word_work:			swpb		&SUS_TXW
						call		#sus_wait
						mov.b		&SUS_TXW, &SUS_TXB
						clrc
						rrc.b		&SUS_TXB
						rrc.b		&SUS_TXB
						rrc.b		&SUS_TXB
						rrc.b		&SUS_TXB
						call		#sus_txnh
						call		#sus_wait
						mov.b		&SUS_TXW, &SUS_TXB
						call		#sus_txnh
						ret
; }}}
sus_sendstr:																	; {{{
; transmit null terminated byte sequence
; --------------------------------------------------------------------------------------------------------------------------------
						push		r4
						mov.w		&SUS_TXW, r4
						call		#sus_wait
sendstr_loop:			mov.b		@r4+, &SUS_TXB
						tst.b		&SUS_TXB
						jz			sendstr_done
						call		#sus_txb
						call		#sus_wait
						jmp			sendstr_loop
sendstr_done:			pop			r4
						ret
; }}}
sus_txb:																		; {{{
; transmit a single byte
; --------------------------------------------------------------------------------------------------------------------------------
						mov.b		#0x0a, &SUS_TXS								; clear state
						clrc
						rlc.w		&SUS_TXB									; 0000 000x xxxx xxx0
						bis.w		&0x0200, &SUS_TXB							; 0000 001x xxxx xxx0 start bit is 0, stop bit is 1
						bis.w		#MC_1, &TACTL
						mov.w		#(TASSEL_2|MC_1), &TACTL					; use DCO, no prescaler, counting up mode
						mov.w		#(CCIE), &TACCTL0							; TACCR0 CCIFG interrupt enable
						mov.w		#0x1a0, &TACCR0								; period of 1e6/2400 ticks
						ret
; }}}
sus_txnh:																		; {{{
; transmit nibble after converting to ascii hex
; --------------------------------------------------------------------------------------------------------------------------------

						and.b		#0x0f, &SUS_TXB
						cmp.b		#0x0a, &SUS_TXB
						jlo			txnh_09
						add.b		#0x27, &SUS_TXB
txnh_09:				add.b		#0x30, &SUS_TXB
						jmp			sus_txb
; }}}
SUS_TACCR0_CCIFG_HANDLER:														; {{{
; interrupt handler for serial transmission
; --------------------------------------------------------------------------------------------------------------------------------
						tst.b		&SUS_TXS
						jz			sus_disable_interrupt
						dec.b		&SUS_TXS
						rrc.w		&SUS_TXB
						jnc			sus_zout
						bis.b		#SUS_TXPIN, &SUS_TXOUT
						reti
sus_zout:				bic.b		#SUS_TXPIN, &SUS_TXOUT
						reti
sus_disable_interrupt:	clr.w		&TACCR0
						clr.w		&TACCTL0
						clr.w		&TACTL
						reti
; }}}

multiply:																		; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						push		r4
						push		r5
						push		r6
						push		r7
						mov.w		#0x0001, r4
						mov.w		&MUL0, r5
						mov.w		&MUL1, r6
						mov.w		#0x0000, &PROL
						mov.w		#0x0000, &PROH
						mov.w		#0x0000, r7

mul_accumulate:			bit.w		r4, r5
						jz			mul_shiftup
						add.w		&PROL, r6
						addc.w		&PROH, r7

mul_shiftup:			clrc
						rlc.w		r4
						jz			mul_return
						rlc.w		r6
						rlc.w		r7
						jmp			mul_accumulate

mul_return:				ret
; }}}
divide:																			; {{{
; --------------------------------------------------------------------------------------------------------------------------------
loopcounter equ r9	; non-overlapping use
shiftbool equ r9	; with different
mask equ r9			; semantics
numerator_h equ r8
numerator_l equ r7
divisor_h equ r6
divisor_l equ r5
quotient equ r4
						push		r4
						push		r5
						push		r6
						push		r7
						push		r8
						push		r9
						mov.w		&NUMERATOR, numerator_h
						mov.w		&DIVISOR, divisor_h

						tst			divisor_h
						jz			out_of_range								; division by zero
						tst			numerator_h
						jz			zero_numerator								; zero divided by x = zero

						push		numerator_h									; NOTE: if numerator/2 >= divisor
						clrc													; quotient will be >= 2 which
						rrc.w		numerator_h									; is oob, so we can take an easy
						cmp			divisor_h, numerator_h						; way out here
						pop			numerator_h
						jhs			out_of_range

						mov.w		#0x8000, mask

find_num_msb_loop:		bit			mask, numerator_h
						jnz			num_msb_found
						clrc
						rrc.w		mask
						jmp			find_num_msb_loop
num_msb_found:

						cmp			mask, divisor_h								; align msb of divisor to numerator
						mov.w		#0x0000, shiftbool							; NOTE: since any ratios >= 2 are taken
						jhs			num_div_aligned								; care of above at most 1 shift is neded
						rla			divisor_h									; and thus no looping
						mov.w		#0x0001, shiftbool
num_div_aligned:		push		shiftbool

						mov.w		#0x0000, quotient
						mov.w		#0x0000, numerator_l
						mov.w		#0x0000, divisor_l
						mov.w		#0x0010, loopcounter

long_division_loop:		cmp.w		numerator_h, divisor_h						; 32 bit comparision: high word
						jlo			div_N_hs_D									; DH-NH < 0 => N >= D
						jeq			div_compare_low_byte						; DH-NH = 0 => N ? D depends on low byte
						jmp			div_N_lo_D									; else DH-NH > 0 divisor is bigger
div_compare_low_byte:
						cmp.w		divisor_l, numerator_l						; 32 bit comparision: low word
						jhs			div_N_hs_D									; NL-DL >= 0 => numerator is higher or same

div_N_lo_D:				clrc
						jmp			division_loop_continue

div_N_hs_D:				sub.w		divisor_l, numerator_l
						subc.w		divisor_h, numerator_h
division_loop_continue:	rlc			quotient
						clrc
						rrc			divisor_h
						rrc			divisor_l

						dec			loopcounter
						tst			loopcounter
						jnz			long_division_loop

						pop			shiftbool
						tst			shiftbool
						jz			division_ret
						clrc
						rlc			quotient

division_ret:			mov.w		quotient, &QUOTIENT
						pop			r9
						pop			r8
						pop			r7
						pop			r6
						pop			r5
						pop			r4
						ret

zero_numerator:			mov.w		#0x0000, quotient
						jmp			division_ret
out_of_range:			mov.w		#0xffff, quotient
						jmp			division_ret
; }}}
