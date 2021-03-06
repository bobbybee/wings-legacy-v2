/*
 * WINGS Operating System
 * Copyright (C) 2016 Alyssa Rosenzweig
 * 
 * This file is part of WINGS.
 * 
 * WINGS is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * WINGS is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with WINGS.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Global Descriptor Table implementation
 */

#include <kgdt.h>
#include <ktextvga.h>

uint8_t gdtTable[8 * 3];

void initGDT() {
    gdtEntry(&gdtTable, 0, 0, 0, 0, GDT_SIZE);
    gdtEntry(&gdtTable, 1, 0, 0xFFFFFFFF, GDT_PRESENT | GDT_RING0 | GDT_RW | GDT_EXECUTABLE, GDT_SIZE);
    gdtEntry(&gdtTable, 2, 0, 0xFFFFFFFF, GDT_PRESENT | GDT_RING0 | GDT_RW, GDT_SIZE);

    struct descriptorPtr ptr;
    ptr.limit = sizeof(gdtTable) - 1;
    ptr.offset = &gdtTable;

    loadGDT(&ptr);

    kputs("GDT loaded\n");
}

void gdtEntry(
        void* table,
        int number,
        void* base,
        uint32_t limit,
        uint8_t access,
        uint8_t flags) {

    if(limit > 0xFFFF) {
        limit = limit >> 12;
        flags |= GDT_GRANULARITY_PAGE;
    }
    
    uint8_t* entry = table + (number * 8);
    uint32_t _base = (uint32_t) base;

    entry[0] = limit & 0x000000FF;
    entry[1] = (limit & 0x000FF00) >> 8;
    entry[2] = _base & 0x000000FF;
    entry[3] = (_base & 0x0000FF00) >> 8;
    entry[4] = (_base & 0x00FF0000) >> 16;
    entry[5] = access;
    entry[6] = ((limit >> 16) & 0xF) | ((flags & 0x0F) << 4);
    entry[7] = (_base & 0xFF000000) >> 24;

    kputs("GDT Entry: ");
    kputnum(number, 10);
    kputs(", base: ");
    kputnum((uint32_t)base, 16);
    kputs(", limit: ");
    kputnum(limit, 16);
    kputs(", access: ");
    kputnum(access, 16);
    kputs(", flags: ");
    kputnum(flags, 16);
    kputchar('\n');
}
