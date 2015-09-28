#import <libactivator/libactivator.h>
#include <dispatch/dispatch.h>
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioServices.h>
#include <IOKit/hid/IOHIDEventSystem.h>
#include <IOKit/hid/IOHIDEventSystemClient.h>
#include <stdio.h>
#include <dlfcn.h>

int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef, int);
typedef struct __IOHIDServiceClient * IOHIDServiceClientRef;
int IOHIDServiceClientSetProperty(IOHIDServiceClientRef, CFStringRef, CFNumberRef);
typedef void* (*clientCreatePointer)(const CFAllocatorRef);
extern "C" void BKSHIDServicesCancelTouchesOnMainDisplay();
typedef void* (*vibratePointer)(SystemSoundID inSystemSoundID, id arg, NSDictionary *vibratePattern);

#ifdef __cplusplus
extern "C" {
#endif

CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);

#ifdef __cplusplus
}
#endif

struct rawTouch {
    float density;
    float radius;
    float quality;
    float x;
    float y;
} lastTouch;

NSUserDefaults *defaults;

BOOL hasIncreasedByPercent(float percent, float value1, float value2) {

    if (value1 <= 0 || value2 <= 0)
        return NO;
    if (value1 >= value2 + (value2 / percent))
        return YES;
    return NO;
}	

static NSString *ForceTouchActivator_eventName = @"ForceTouchActivatorEvent";

@interface ForceTouchActivatorDataSource : NSObject <LAEventDataSource> {}

+ (id)sharedInstance;
void prefsUpdate();

@end

@implementation ForceTouchActivatorDataSource

+ (id)sharedInstance {
	static id sharedInstance = nil;
	static dispatch_once_t token = 0;
	dispatch_once(&token, ^{
		sharedInstance = [self new];
	});
	return sharedInstance;
}

+ (void)load {
	[self sharedInstance];
}

- (id)init {
	if ((self = [super init])) {
		// Register our event
		if (LASharedActivator.isRunningInsideSpringBoard) {
			[LASharedActivator registerEventDataSource:self forEventName:ForceTouchActivator_eventName];
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), (CFNotificationCallback)prefsUpdate, (CFStringRef)@"prefsUpdate", NULL, CFNotificationSuspensionBehaviorDrop);
            prefsUpdate();
		}
	}
	return self;
}

void prefsUpdate() {    
    defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ethanarbuckle.forcetouchactivator"];
    [defaults registerDefaults:@{ @"isEnabled" : @YES,
                                        @"sensitivity" : @20,
                                    }];
}

- (void)dealloc {
	if (LASharedActivator.isRunningInsideSpringBoard) {
		[LASharedActivator unregisterEventDataSourceWithEventName:ForceTouchActivator_eventName];
	}
	[super dealloc];
}

- (NSString *)localizedTitleForEventName:(NSString *)eventName {
	return @"ForceTouch";
}

- (NSString *)localizedGroupForEventName:(NSString *)eventName {
	return @"ForceTouch";
}

- (NSString *)localizedDescriptionForEventName:(NSString *)eventName {
	return @"Firmly press anywhere on the screen to invoke ForceTouch";
}

- (BOOL)eventWithName:(NSString *)eventName isCompatibleWithMode:(NSString *)eventMode {
	return YES;
}

@end

void touch_event(void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef event) {

    if (IOHIDEventGetType(event) == kIOHIDEventTypeDigitizer) {

        //get child events (individual finger)
        NSArray *children = (NSArray *)IOHIDEventGetChildren(event);
        if ([children count] == 1) { //single touch

            struct rawTouch touch;

            touch.density = IOHIDEventGetFloatValue((__IOHIDEvent *)children[0], (IOHIDEventField)kIOHIDEventFieldDigitizerDensity);
            touch.radius = IOHIDEventGetFloatValue((__IOHIDEvent *)children[0], (IOHIDEventField)kIOHIDEventFieldDigitizerMajorRadius);
            touch.quality = IOHIDEventGetFloatValue((__IOHIDEvent *)children[0], (IOHIDEventField)kIOHIDEventFieldDigitizerQuality);
            touch.x = IOHIDEventGetFloatValue((__IOHIDEvent *)children[0], (IOHIDEventField)kIOHIDEventFieldDigitizerX) * [[UIScreen mainScreen] bounds].size.width;
            touch.y = IOHIDEventGetFloatValue((__IOHIDEvent *)children[0], (IOHIDEventField)kIOHIDEventFieldDigitizerY) * [[UIScreen mainScreen] bounds].size.height; 
            
            float change = [defaults floatForKey:@"sensitivity"];
            NSLog(@"change %f", change);
           
            if ([defaults boolForKey:@"isEnabled"] && hasIncreasedByPercent(change, touch.density, lastTouch.density) && hasIncreasedByPercent(change, touch.radius, lastTouch.radius) && hasIncreasedByPercent(5, touch.quality, lastTouch.quality)) {
                
                //make sure we arent being triggered by some swipe by canceling out touches that go beyond 10px of orig touch
                if ((lastTouch.x - touch.x >= 10 || lastTouch.x - touch.x <= -10) || (lastTouch.y - touch.y >= 10 || lastTouch.y - touch.y <= -10)) {
                    return;
                }

                //trigger event
                LAEvent *event = [LAEvent eventWithName:ForceTouchActivator_eventName mode:[LASharedActivator currentEventMode]];
                [LASharedActivator sendEventToListener:event];

                if ([event isHandled]) {

                    BKSHIDServicesCancelTouchesOnMainDisplay();

                    NSMutableArray *vPattern = [NSMutableArray array];
                    [vPattern addObject:[NSNumber numberWithBool:YES]];
                    [vPattern addObject:[NSNumber numberWithInt:100]];
                    NSDictionary *vDict = @{ @"VibePattern" : vPattern, @"Intensity" : @1 };

                    vibratePointer vibrate;
                    void *handle = dlopen(0, 9);
                    *(void**)(&vibrate) = dlsym(handle,"AudioServicesPlaySystemSoundWithVibration");
                    vibrate(kSystemSoundID_Vibrate, nil, vDict);


                }

            }

            lastTouch = touch;
        }
    }
}

%ctor {

    [ForceTouchActivatorDataSource sharedInstance];
    clientCreatePointer clientCreate;
    void *handle = dlopen(0, 9);
    *(void**)(&clientCreate) = dlsym(handle,"IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientRef ioHIDEventSystem = (__IOHIDEventSystemClient *)clientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientScheduleWithRunLoop(ioHIDEventSystem, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDEventSystemClientRegisterEventCallback(ioHIDEventSystem, (IOHIDEventSystemClientEventCallback)touch_event, NULL, NULL);
    ;

}
