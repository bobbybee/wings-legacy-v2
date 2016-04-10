/**
 * WINGS
 * welcome to kernel space!
 */

#include <kstandard.h>
#include <ktextvga.h>
#include <kgdt.h>
#include <kidt.h>

void initPIC();
void maskPIC(int master, int slave);

void kmain() {
    kputs("Hello, World!\n");

    __asm__("cli");
    initGDT();
    initIDT();
    initPIC();
    maskPIC(0xFD, 0xFF);
    __asm__("sti");

    __asm__("int $0");
    __asm__("int $1");
    __asm__("int $2");
    __asm__("int $3");
    __asm__("int $4");
    __asm__("int $5");
    for(;;);
}
