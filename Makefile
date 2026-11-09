TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = freefireth
ARCHS = arm64 arm64e

export PATH := /opt/homebrew/bin:$(PATH)

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FFPanel
FFPanel_FILES = Tweak.xm Panel.mm MenuView.mm AntiBan.mm Memory.mm
FFPanel_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
FFPanel_FRAMEWORKS = UIKit CoreGraphics QuartzCore Foundation
FFPanel_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

# after package: also drop a standalone dylib for injectors that hate debs
after-package::
	@echo "==== FFPanel package ready ===="
	@mkdir -p packages
	@# Theos puts the signed dylib under .theos/obj/
	@if [ -f .theos/obj/FFPanel.dylib ]; then \
		cp -f .theos/obj/FFPanel.dylib packages/FFPanel.dylib; \
		echo "copied packages/FFPanel.dylib"; \
	fi
	@if [ -f .theos/obj/arm64/FFPanel.dylib ]; then \
		cp -f .theos/obj/arm64/FFPanel.dylib packages/FFPanel.arm64.dylib; \
	fi
	@if [ -f .theos/obj/arm64e/FFPanel.dylib ]; then \
		cp -f .theos/obj/arm64e/FFPanel.dylib packages/FFPanel.arm64e.dylib; \
	fi
	@ls -la packages/ || true
	@find packages -type f 2>/dev/null || true
