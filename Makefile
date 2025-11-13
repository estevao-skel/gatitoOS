ASM = nasm
ASMFLAGS = -f bin
QEMU = qemu-system-i386
QEMU_FLAGS = -drive file=gatito.img,format=raw,if=ide -m 32M

.PHONY: all run clean

all: gatito.img

gatito.img: bootloader.bin kernel.bin output.gat
	@echo "Criando imagem de disco Gatito OS..."
	dd if=/dev/zero of=gatito.img bs=512 count=2880 status=none
	dd if=bootloader.bin of=gatito.img conv=notrunc status=none
	dd if=kernel.bin of=gatito.img bs=512 seek=1 conv=notrunc status=none
	dd if=output.gat of=gatito.img bs=512 seek=65 conv=notrunc status=none
	@echo "Imagem gatito.img criada com sucesso!"

bootloader.bin: bootloader.asm
	@echo "Compilando bootloader..."
	$(ASM) $(ASMFLAGS) bootloader.asm -o bootloader.bin

kernel.bin: kernel.asm
	@echo "Compilando kernel..."
	$(ASM) $(ASMFLAGS) kernel.asm -o kernel.bin

output.gat:
	@echo "output.gat não encontrado, criando placeholder..."
	python3 -c "data = bytearray([x%256 for x in range(64000)]); open('output.gat','wb').write(data)"
	@echo "✓ output.gat criado (64000 bytes)"

run: gatito.img
	@echo "Iniciando Gatito OS..."
	$(QEMU) $(QEMU_FLAGS)

clean:
	@echo "Limpando arquivos..."
	rm -f bootloader.bin kernel.bin gatito.img output.gat
