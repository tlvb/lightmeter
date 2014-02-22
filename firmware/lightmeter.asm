.include "msp430g2x31.inc"
; vim: set syntax=msp:

dly_dit equ 0x4fff
dly_dah equ 0xeffd

usout equ P1OUT
usdir equ P1DIR



SUS_TXPIN equ 0x02
SUS_TXDIR equ P1DIR
SUS_TXOUT equ P1OUT
// static softusart variables
SUS_TXB equ 0x0200
SUS_TXS equ 0x0202

c0l equ 0x0204
c0h equ 0x0205
c1l equ 0x0206
c1h equ 0x0207
NUMERATOR equ 0x0208
DIVISOR equ 0x020a
QUOTIENT equ 0x020c
QUOTIENTL equ 0x020c
QUOTIENTH equ 0x020d


org 0xfff2
interrupt_table:																; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						dw			SUS_TACCR0_CCIFG_HANDLER
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT
						dw			MAIN_ENTRY_POINT							; set reset vector to point to the MAIN_ENTRY_POINT label
; }}}
org 0xf800
MAIN_ENTRY_POINT:																; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						mov.w		#0x0280, sp
						mov.w		#(WDTPW|WDTHOLD), &WDTCTL

						clr.b		&DCOCTL
						mov.b		&0x10ff, &BCSCTL1
						mov.b		&0x10fe, &DCOCTL

						bis.b		#0x03, &P1DIR
						call		#configure_i2c_master
						call		#sus_setup
						eint

						call		#generate_start
						mov.b		#0x72, &USISRL
						call		#transmit_byte_get_ack
						mov.b		#0x80, &USISRL
						call		#transmit_byte_get_ack
						mov.b		#0x03, &USISRL								; power up
						call		#transmit_byte_get_ack
						call		#generate_stop

						call		#generate_start
						mov.b		#0x72, &USISRL
						call		#transmit_byte_get_ack
						mov.b		#0x81, &USISRL
						call		#transmit_byte_get_ack
						mov.b		#0x12, &USISRL								; long integration time and high gain
						call		#transmit_byte_get_ack
						call		#generate_stop

IDLE_LOOP_START:
						call		#red_led_on

;						call		#generate_start
;						mov.b		#0x72, &USISRL
;						call		#transmit_byte_get_ack
;						mov.b		#0x90, &USISRL								; read control register
;						call		#transmit_byte_get_ack
;
;						call		#generate_restart
;
;						mov.b		#0x73, &USISRL
;						call		#transmit_byte_get_ack
;						call		#receive_byte_set_nack
;						call		#generate_stop
;
;
;						call		#generate_start
;						mov.b		#0x72, &USISRL
;						call		#transmit_byte_get_ack
;						mov.b		#0x9a, &USISRL								; read id register
;						call		#transmit_byte_get_ack
;
;						call		#generate_restart
;
;						mov.b		#0x73, &USISRL
;						call		#transmit_byte_get_ack
;						call		#receive_byte_set_nack
;						call		#generate_stop


						call		#generate_start
						mov.b		#0x72, &USISRL
						call		#transmit_byte_get_ack
						mov.b		#0x9c, &USISRL								; adc block read
						call		#transmit_byte_get_ack

						call		#generate_restart

						mov.b		#0x73, &USISRL
						call		#transmit_byte_get_ack
						call		#receive_byte_set_ack
						mov.b		r5, &c0l
						call		#receive_byte_set_ack
						mov.b		r5, &c0h
						call		#receive_byte_set_ack
						mov.b		r5, &c1l
						call		#receive_byte_set_nack
						mov.b		r5, &c1h
						call		#generate_stop

txw_0:					tst			&SUS_TXS
						jnz			txw_0
						mov.b		#0x00, &SUS_TXB								; canary 0
						call		#sus_transmit

txw_1:					tst			&SUS_TXS
						jnz			txw_1
						mov.b		#0x00, &SUS_TXB								; canary 1
						call		#sus_transmit

txw_2:					tst			&SUS_TXS
						jnz			txw_2
						mov.b		#0xff, &SUS_TXB								; canary 2
						call		#sus_transmit

txw_3:					tst			&SUS_TXS
						jnz			txw_3
						mov.b		#0xff, &SUS_TXB								; canary 3
						call		#sus_transmit

txw_4:					tst			&SUS_TXS
						jnz			txw_4
						mov.b		&c0l, &SUS_TXB								; channel 0 low
						call		#sus_transmit

txw_5:					tst			&SUS_TXS
						jnz			txw_5
						mov.b		&c0h, &SUS_TXB								; channel 0 high
						call		#sus_transmit

txw_6:					tst			&SUS_TXS
						jnz			txw_6
						mov.b		&c1l, &SUS_TXB								; channel 1 low
						call		#sus_transmit

txw_7:					tst			&SUS_TXS
						jnz			txw_7										; channel 1 high
						mov.b		&c1h, &SUS_TXB
						call		#sus_transmit

						mov.w		&c1l, &NUMERATOR
						mov.w		&c0l, &DIVISOR
						call		#divide

txw_8:					tst			&SUS_TXS
						jnz			txw_8										; quotient low
						mov.b		&QUOTIENTL, &SUS_TXB
						call		#sus_transmit

txw_9:					tst			&SUS_TXS
						jnz			txw_9										; quotient high
						mov.b		&QUOTIENTH, &SUS_TXB
						call		#sus_transmit

						call		#red_led_off
						mov.w		#0xffff, r7
bigdelay:				dec.w		r7
						nop
						nop
						nop
						nop
						jnz			bigdelay
						jmp			IDLE_LOOP_START

; }}}
red_led_on:																		; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						bis.b		#0x01, &P1OUT
						ret
; }}}
red_led_off:																	; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						bic.b		#0x01, &P1OUT
						ret
; }}}
divide:																			; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						push		r4
						push		r5
						push		r6
						push		r7
						mov.w		&NUMERATOR, r6
						mov.w		&DIVISOR, r5
						mov.w		#0x0000, r4

						tst.w		r5
						jz			divider_ret

						mov.w		#0x0200, r7

dec_until_lo:			tst			r5
						jz			next_power
						cmp			r5, r6										; r5 >= r6?
						jlo			next_power									; nope
						sub.w		r5, r6										; yes
						add.w		r7, r4										; increase r4 by current bit value
						jmp			dec_until_lo

next_power:				clrc
						rrc.w		r7
						clrc
						rrc.w		r5
						tst			r7
						jnz			dec_until_lo

divider_ret:			mov.w		r4, &QUOTIENT
						pop			r7
						pop			r6
						pop			r5
						pop			r4
						ret
; }}}
configure_i2c_master:															; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						bis.b		#USISWRST, &USICTL0							; put in reset mode
						bis.b		#(USIPE6|USIPE7|USIMST), &USICTL0			; port enable and master transmit mode
						bis.b		#USII2C, &USICTL1							; enable i2c mode
						bis.b		#(USIDIV_5|USISSEL_2|USICKPL), &USICKCTL	; clock prescaler source and polarity select
						bic.b		#USISWRST, &USICTL0
						ret
; }}}
transmit_byte_get_ack:															; {{{
;						ARG:		r4: ack aggregate so far
;						RET:		r4: r4 shifted left | last ack value
; --------------------------------------------------------------------------------------------------------------------------------

						bis.b		#USIOE, &USICTL0							; enable output
						mov.b		#0x08, &USICNT								; send 8 bits
transmit_byte_wait0:	bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			transmit_byte_wait0							; loop if not

						bic.b		#USIOE, &USICTL0							; disable output
						mov.b		#0x01, &USICNT								; receive one bit
transmit_byte_wait1:	bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			transmit_byte_wait1							; loop if not
						bis.b		#USIOE, &USICTL0							; enable output

						add.w		r4, r4										; shift r4 to left
						bis.b		&USISRL, r4

						ret
; }}}
receive_byte_set_ack:	; and receive_byte_set_nack:												; {{{
;						ARG:		- none -
;						RET:		r5: received data
; --------------------------------------------------------------------------------------------------------------------------------
						push		r6
						mov.b		#0x00, r6
						jmp			receive_byte_set_acknack
receive_byte_set_nack:
						push		r6
						mov.b		#0xff, r6
receive_byte_set_acknack:

						bic.b		#USIOE, &USICTL0							; disable output
						mov.b		#0x08, &USICNT								; receive eight bits
receive_one_byte_wait0:	bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			receive_one_byte_wait0						; loop if not
						mov.b		&USISRL, r5									; harvest received data

						bis.b		#USIOE, &USICTL0							; enable output
						mov.b		r6, &USISRL									; ack or nack bit
						mov.b		#0x01, &USICNT								; write one bit
receive_one_byte_wait1:	bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			receive_one_byte_wait1						; loop if not

						pop			r6
						ret
; }}}
generate_start:																	; {{{
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
generate_restart:																	; {{{
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
generate_restart_wait:	bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			generate_restart_wait							; loop if not
						mov.b		#0x00, &USISRL								; msb = 0
						bis.b		#USIGE, &USICTL0							; make latch transparent (1)
						bic.b		#(USIGE|USIOE), &USICTL0					; disable output
						ret
; }}}
generate_stop:																	; {{{
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
generate_stop_wait:		bit.b		#USIIFG, &USICTL1							; check if flag is set
						jz			generate_stop_wait							; loop if not
						mov.b		#0xff, &USISRL								; msb = 1
						bis.b		#USIGE, &USICTL0							; make latch transparent (1)
						bic.b		#(USIGE|USIOE), &USICTL0					; disable output

						ret
; }}}
sus_setup:																	; {{{
; --------------------------------------------------------------------------------------------------------------------------------
						mov.w		#0x0000, &SUS_TXS
						bis.b		#SUS_TXPIN, &SUS_TXDIR
						bis.b		#SUS_TXPIN, &SUS_TXOUT
						clr.w		&TACCR0
						clr.w		&TACCTL0
						clr.w		&TACTL
						ret
; }}}
sus_transmit:																	; {{{
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
SUS_TACCR0_CCIFG_HANDLER:														; {{{
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




