# MiSO Desktop - atajos de desarrollo
# Los comandos que requieren root usan sudo.

SHELL := /bin/bash
PROFILE ?= desktop
ISO_CORE := out/miso-desktop-0.1.0-core-amd64.iso
ISO_DESKTOP := out/miso-desktop-0.1.0-desktop-amd64.iso

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
	@echo "  make run            Arranca la ISO core en QEMU (BIOS)"
	@echo "  make run-uefi       Arranca la ISO core en QEMU (UEFI)"
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
	powershell -ExecutionPolicy Bypass -File scripts/run-qemu.ps1 -Iso "$(ISO_CORE)"

run-uefi:
	powershell -ExecutionPolicy Bypass -File scripts/run-qemu.ps1 -Iso "$(ISO_CORE)" -Uefi

clean:
	sudo bash build/clean.sh

shellcheck:
	shellcheck build/*.sh build/lib/*.sh tools/bin/* tools/libexec/* branding/*.sh pjd-shell/*.sh scripts/*.sh

validate:
	python3 tests/validate_yaml.py
	python3 tests/validate_calamares.py

check: shellcheck validate
	@echo "OK"
