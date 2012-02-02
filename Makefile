include theos/makefiles/common.mk

TWEAK_NAME = SwipeShiftCaret
SwipeShiftCaret_FILES = Tweak.xm
SwipeShiftCaret_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
