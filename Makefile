ifeq ($(ROOTLESS),1)
	THEOS_PACKAGE_SCHEME = rootless
endif

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	ARCHS = arm64 arm64e
	TARGET = iphone:clang:14.4:15.0
else
	TARGET = iphone:clang::5.0
	ARCHS = armv7 arm64 arm64e
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SwipeShiftCaret
SwipeShiftCaret_FILES = SwipeShiftCaret.x
SwipeShiftCaret_FRAMEWORKS = UIKit
SwipeShiftCaret_USE_SUBSTRATE = 0
SwipeShiftCaret_LOGOSFLAGS = -c generator=internal
SwipeShiftCaret_LDFLAGS = -Wl,-segalign,4000
# ADDITIONAL_CFLAGS = -DDEBUG

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Preferences MobileNotes"
