#include <kstandard.h>
#include <ktextvga.h>
#include <kps2keyboard.h>

// generic interrupt handler

void isrHandler(uint32_t number) {
    kputs("Received interrupt: ");
    kputnum(number, 16);
    kputchar('\n');
}

void irqHandler(uint32_t number) {
    if(number == 1) {
        ps2KeyboardIRQ();
    } else {
        kputs("Received unhandled IRQ: ");
        kputnum(number, 16);
        kputchar('\n');
    }

    // acknowledge IRQ
    if(number > 0x8) outb(0xA0, 0x20);
    outb(0x20, 0x20);
}
