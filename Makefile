include theos/makefiles/common.mk

TWEAK_NAME = ForceTouchActivator
ForceTouchActivator_FILES = Event.xm
ForceTouchActivator_LIBRARIES = activator
ForceTouchActivator_FRAMEWORKS = UIKit CoreGraphics 
ForceTouchActivator_PRIVATE_FRAMEWORKS = IOKit BackBoardServices AudioToolbox

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
SUBPROJECTS += forcetouchactivator_prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
