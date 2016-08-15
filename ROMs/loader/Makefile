CP = copy
RM = rm -f
CC = sdcc
AS = sdasz80
LD = sdcc
MKBIN = makebin
H2B = hex2bin
MIF = srec_cat

SDIR = src
IDIR = inc
ODIR = obj

CFLAGS = -mz80 --opt-code-size --fomit-frame-pointer -I$(IDIR) -I..
LDFLAGS = -mz80 --code-loc 0x0100 --data-loc 0x6000 --no-std-crt0

_OBJS = crt0.rel main.rel joy.rel mmc.rel fat.rel vdp.rel
OBJS = $(patsubst %,$(ODIR)/%,$(_OBJS))

all: loader.mif

loader.mif: loader.bin
	fillfile $< 8192
	$(MIF) --Output $@ -Memory_Initialization_File 8 $< -Binary

loader.bin: loader.ihx

loader.ihx: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

.PHONY: clean

clean:
	$(RM) $(ODIR)/* *.map *.lk *.noi *.bin *.ihx *.mif

$(ODIR)/%.rel: $(SDIR)/%.S
	$(AS) -o $@ $<

$(ODIR)/%.rel: $(SDIR)/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.bin: %.ihx
	$(H2B) -e bin $<
