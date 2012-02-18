include theos/makefiles/common.mk

TWEAK_NAME = SwipeShiftCaret
SwipeShiftCaret_FILES = SwipeShiftCaret.x
SwipeShiftCaret_FRAMEWORKS = UIKit
SwipeShiftCaret_LDFLAGS = -lactivator

include $(THEOS_MAKE_PATH)/tweak.mk
