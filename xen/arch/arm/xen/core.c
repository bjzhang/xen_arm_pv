/*
 * core.c
 *
 * Copyright (C) 2008-2011 Samsung Electronics
 *          Sang-bum Suh <sbuk.suh@samsung.com>
 *          JaeMin Ryu   <jm77.ryu@samsung.com>
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

#include <xen/config.h>
#include <xen/linkage.h>
#include <xen/lib.h>
#include <xen/types.h>
#include <xen/init.h>

#include "asm/core.h"

int detect_core(void)
{
	unsigned long id;

	__asm__ __volatile__("mrc p15, 0, %0, c0, c0, 0" : "=r"(id) : : "memory");

	return id;
}

