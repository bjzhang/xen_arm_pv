/*
 * start.S 
 *
 * Copyright (C) 2012 Suse
 *         Bamvor Jian Zhang <bjzhang@suse.com>
 * copy from tegra/start.S
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public version 2 of License as published by
 * the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <xen/autoconf.h>
#include <xen/linkage.h>
#include <xen/config.h>
#include <asm/cpu-domain.h>
#include <asm/pgtable.h>
#include <asm/page.h>
#include <asm/system.h>
#include <asm/memmap.h>


#define TTB_S		(1 << 1)
#define TTB_RGN_NC	(0 << 3)
#define TTB_RGN_OC_WBWA	(1 << 3)
#define TTB_RGN_OC_WT	(2 << 3)
#define TTB_RGN_OC_WB	(3 << 3)
#define TTB_NOS		(1 << 5)
#define TTB_IRGN_NC	((0 << 0) | (0 << 6))
#define TTB_IRGN_WBWA	((0 << 0) | (1 << 6))
#define TTB_IRGN_WT	((1 << 0) | (0 << 6))
#define TTB_IRGN_WB	((1 << 0) | (1 << 6))

#define TTB_FLAGS	TTB_IRGN_WBWA|TTB_S|TTB_NOS|TTB_RGN_OC_WBWA

        .type   text, %function
ENTRY(text)
	msr     cpsr_c, #(PSR_F_BIT | PSR_I_BIT | PSR_MODE_SVC)
	adr     r1, __SRA_INFO
	str     r0, [r1, #0]

	adr	r1, text
	ldr	r2, =(MEMMAP_HYPERVISOR_BASE + 0x8000)
	mov	r5, r2
	mov	r3, #0x200000	@ Code size

1:
	ldr	r4, [r1], #4
	str	r4, [r2], #4
	sub	r3, r3, #4
	cmp	r3, #0
	bne	1b

	adr	r2, ttb_setup
	adr	r1, text
	sub	r2, r2, r1	@ ttb_setup - text
	add	r5, r5, r2

	mov	pc, r5

	/* clear page table area */
ttb_setup:
	adr	r0, text
	mov	r1, r0
	sub	r0, r0, #0x4000	
	mov	r2, #0
1:	str	r2, [r1, #-4]!
	str	r2, [r1, #-4]!
	str	r2, [r1, #-4]!
	str	r2, [r1, #-4]!
	cmp	r0, r1
	bne	1b

	adr	r4, mem_map_table
	b	2f

1:
	str	r3, [r0, r2]
	add	r2, r2, #4
	add	r3, r3, #0x100000
	adds	r1, r1, #-1
	bhi	1b
2:
	ldmia	r4!, {r1, r2, r3}
	cmp	r1, #0
	bne	1b

	orr	r0, r0, #TTB_FLAGS		@ for WBWA/S 
	mcr	p15, 0, r0, c2, c0, 0		@ Load TTB0
	mcr	p15, 0, r0, c2, c0, 1		@ Load TTB1

	@ TTBCR Setting
	mrc	p15, 0, r5, c1, c0, 2
	orr	r5,r5, #((3 << (10 * 2)) |(3 << (11 * 2)))
	mcr	p15, 0, r5, c1, c0, 2

	ldr	r5, =0xff0a89a8
	ldr	r6, =0x40e040e0
	mcr	p15, 0, r5, c10, c2, 0		@ write PRRR
	mcr	p15, 0, r6, c10, c2, 1		@ write NMRR

dac_setup:
	mov	r5, #(DOMAIN_VALUE(DOMAIN_SUPERVISOR, DOMAIN_MANAGER)	| \
		      DOMAIN_VALUE(DOMAIN_HYPERVISOR, DOMAIN_MANAGER)	| \
		      DOMAIN_VALUE(DOMAIN_USER, DOMAIN_MANAGER)		| \
		      DOMAIN_VALUE(DOMAIN_IO, DOMAIN_CLIENT))

	mcr	p15, 0, r5, c3, c0, 0		@ Load DAC

	adr	r5, v7_crval 
	ldmia	r5, {r5, r6} 
	mrc	p15, 0, r0, c1, c0, 0	@ read control register 
	bic	r0, r0, r5		@ clear bits them 
	orr	r0, r0, r6		@ set them 

#ifdef CONFIG_USE_HIGH_VECTORS
	orr	r0, r0, #CR_V
#else
	bic	r0, r0, #CR_V
#endif

	mcr	p15, 0, r0, c1, c0, 0	@ Turn on MMU
	mov	r0, r0
	mov	r0, r0
	mov	r0, r0

	mov	ip, #0
	mcr	p15, 0, ip, c8, c7, 0	@ Invalidate I, D TLBs
	dsb
	isb

	b	clear_bss

	/*   AT
	 *  TFR   EV X F   I D LR    S
	 * .EEE ..EE PUI. .T.T 4RVI ZWRS BLDP WCAM
	 * rxxx rrxx xxx0 0101 xxxx xxxx x111 xxxx < forced
	 *    1    0 110       0011 1100 .111 1101 < we want
	 */
	
	.type   v7_crval, #object 
v7_crval: 
	.long	0x0120c302
	.long 	0x10c03c7d


1:	.word   _sbss
	.word   _ebss

clear_bss:
	adr     r0, 1b
	ldmia   r0, {r1, r2}
	mov     r0, #0
1:
	str     r0, [r1], #4 
	cmp     r1, r2
	blo     1b

stack_setup:
        /* Stack Setup */
        mrc     p15, 0, r4, c0, c0, 5           @ get processor id
        and     r4, r4, #15			@ CPU ID masking

        mov     r1, #STACK_SIZE
        mul     r4, r4, r1                         @ r0 = r0 * STACK_SIZE

	msr	cpsr_c, #PSR_MODE_IRQ | PSR_I_BIT | PSR_F_BIT
	ldr     sp, =(irq_stacks + STACK_SIZE)
	add	sp, sp, r4
		
	msr     cpsr_c, #PSR_MODE_ABT | PSR_I_BIT | PSR_F_BIT
	ldr     sp, =(abt_stacks + STACK_SIZE)
	add	sp, sp, r4
				
	msr     cpsr_c, #PSR_MODE_UND | PSR_I_BIT | PSR_F_BIT
	ldr     sp, =(und_stacks + STACK_SIZE)
	add	sp, sp, r4
						
	msr     cpsr_c, #PSR_MODE_SVC | PSR_I_BIT | PSR_F_BIT
	ldr     sp, =(svc_stacks + STACK_SIZE)
	add	sp, sp, r4

	adr     r12, 1f
	ldmia   r12, {lr, pc}

1:
	.long   start_xen
	.long	platform_setup

mem_map_table:
	MAP_ENTRY(0x00000000, 0x00000000, 1024, PDE_TYPE_HYPERVISOR)
	MAP_ENTRY(0xFF000000, MEMMAP_HYPERVISOR_BASE, 0xB, PDE_TYPE_HYPERVISOR)
	MAP_ENTRY(IO_ADDRESS(0x50000000), 0x50000000, 1, PDE_TYPE_IO)
	MAP_ENTRY(IO_ADDRESS(0x60000000), 0x60000000, 1, PDE_TYPE_IO)
	MAP_ENTRY(IO_ADDRESS(0x70000000), 0x70000000, 1, PDE_TYPE_IO)
	MAP_ENTRY(0,0,0,0)

/* \TODO what is it? */
ENTRY(sra_info_ptr)
__SRA_INFO:
	.long	0

	.section .bss.stack_aligned,"w"
/*
 * Initial stack for core 0
 */
svc_stacks: .fill STACK_SIZE,4, 0
irq_stacks: .fill STACK_SIZE,4, 0
abt_stacks: .fill STACK_SIZE,4, 0
und_stacks: .fill STACK_SIZE,4, 0

