TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = freefireth
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FFPanel
FFPanel_FILES = Tweak.xm Panel.mm MenuView.mm AntiBan.mm Memory.mm
FFPanel_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-deprecated-declarations
FFPanel_FRAMEWORKS = UIKit CoreGraphics QuartzCore Foundation
FFPanel_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
	@echo "==== FFPanel package ready ===="
	@ls -la packages/