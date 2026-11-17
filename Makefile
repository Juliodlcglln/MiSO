# MiSO Desktop - atajos de desarrollo
# Los comandos que requieren root usan sudo.

SHELL := /bin/bash
PROFILE ?= desktop
MEMORY ?= 4G
AUDIO ?= sdl
# ISO del perfil activo: make run PROFILE=core usa la ISO core, etc.
ISO ?= out/miso-desktop-0.1.0-$(PROFILE)-amd64.iso
# PowerShell de Windows (desde WSL); se puede sobreescribir: make run PWSH=/ruta/powershell.exe
PWSH ?= $(shell command -v powershell.exe 2>/dev/null || echo /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe)

.PHONY: help deps build build-core build-desktop build-lab kernel run run-uefi clean check shellcheck validate

help:
	@echo "MiSO Desktop"
	@echo ""
	@echo "  make deps           Instala dependencias del host (sudo)"
	@echo "  make build          Construye la ISO del perfil desktop"
	@echo "  make build-core     Construye la ISO del perfil core"
	@echo "  make build-desktop  Construye la ISO del perfil desktop"
	@echo "  make build-lab      Construye la ISO del perfil lab"
	@echo "  make kernel         Compila el kernel MiSO y sus .deb"
	@echo "  make run            Arranca la ISO del perfil actual en QEMU (BIOS)"
	@echo "  make run-uefi       Arranca la ISO del perfil actual en QEMU (UEFI)"
	@echo "  make clean          Limpia artefactos de build"
	@echo "  make shellcheck     Revisa los scripts con shellcheck"
	@echo "  make validate       Valida YAML/JSON del repositorio"
	@echo ""
	@echo "PROFILE=$(PROFILE)"

deps:
	sudo bash build/install-host-deps.sh

build: build-$(PROFILE)

build-core:
	sudo bash build/build-iso.sh --profile core

build-desktop:
	sudo bash build/build-iso.sh --profile desktop

build-lab:
	sudo bash build/build-iso.sh --profile lab

kernel:
	sudo bash kernel/build-kernel.sh

run:
	$(PWSH) -ExecutionPolicy Bypass -File scripts/run-qemu.ps1 -Iso "$(ISO)" -Memory $(MEMORY) -Audio $(AUDIO)

run-uefi:
	$(PWSH) -ExecutionPolicy Bypass -File scripts/run-qemu.ps1 -Iso "$(ISO)" -Memory $(MEMORY) -Audio $(AUDIO) -Uefi

clean:
	sudo bash build/clean.sh

shellcheck:
	shellcheck build/*.sh build/lib/*.sh tools/bin/* tools/libexec/* branding/*.sh pjd-shell/*.sh scripts/*.sh

validate:
	python3 tests/validate_yaml.py
	python3 tests/validate_calamares.py

check: shellcheck validate
	@echo "OK"
