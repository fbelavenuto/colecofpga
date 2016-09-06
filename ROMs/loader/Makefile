CP = copy
RM = rm -f
CC = sdcc
AS = sdasz80
LD = sdcc
MKBIN = makebin
H2B = hex2bin
SRCAT = srec_cat
ROMGEN = romgen

SDIR = src
IDIR = inc
ODIR = obj

CFLAGS = -mz80 --opt-code-size --fomit-frame-pointer -I$(IDIR) -I..
LDFLAGS = -mz80 --code-loc 0x0100 --data-loc 0x6000 --no-std-crt0

_OBJS = crt0.rel main.rel joy.rel mmc.rel fat.rel vdp.rel
OBJS = $(patsubst %,$(ODIR)/%,$(_OBJS))

all: loader

loader: loader.bin
	fillfile $< 8192
#	$(SRCAT) $< --bin -o $@.mif --mif 8
	$(ROMGEN) $< loaderrom a r > ../../src/rom/loaderrom.vhd

loader.bin: loader.ihx

loader.ihx: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $(OBJS)

.PHONY: clean

clean:
	$(RM) $(ODIR)/* *.map *.lk *.noi *.bin *.ihx

$(ODIR)/%.rel: $(SDIR)/%.S
	$(AS) -o $@ $<

$(ODIR)/%.rel: $(SDIR)/%.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.bin: %.ihx
	$(H2B) -e bin $<
