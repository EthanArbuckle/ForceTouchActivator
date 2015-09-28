#import <Preferences/Preferences.h>

@interface PrefsView : UIView  <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, retain) NSUserDefaults *defaults;
- (void)cellSwitchChanged:(UISwitch *)cellSwitch;
- (void)cellSliderChanged:(UISlider *)slider;
@end

#ifdef __cplusplus
extern "C" {
#endif

CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);

#ifdef __cplusplus
}
#endif

@implementation PrefsView

- (id)init {

	if (self = [super initWithFrame:[[UIScreen mainScreen] bounds]]) {

		_defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.ethanarbuckle.forcetouchactivator"];
		[_defaults registerDefaults:@{ @"isEnabled" : @YES,
										@"sensitivity" : @20,
									}];

		//PULL BOUNDS DOWN BELOW NAV BAR
		CGRect frame = [self frame];
		frame.origin.y = 44;
		[self setFrame:frame];

		UITableView *tableView = [[UITableView alloc] initWithFrame:[[UIScreen mainScreen] bounds] style:UITableViewStyleGrouped];
		[tableView setDelegate:self];
		[tableView setDataSource:self];
		[self addSubview:tableView];


	} 

	return self;

}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

	if (section == 0)
		return @"preferences";
	else if (section == 1)
		return @"sensitivity";

	return @"";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

	return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@""];

	if ([indexPath section] == 0 && [indexPath row] == 0) {

		UISwitch *cellSwitch = [[UISwitch alloc] init];
		[cellSwitch setOn:[_defaults boolForKey:@"isEnabled"]];
		[cellSwitch addTarget:self action:@selector(cellSwitchChanged:) forControlEvents:UIControlEventValueChanged];
		[cell setAccessoryView:cellSwitch];
		[[cell textLabel] setText:@"Enabled"];

	}
	else if ([indexPath row] == 0 && [indexPath section] == 1) {

		UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(20, ([cell frame].size.height / 2) - 10, [[UIScreen mainScreen] bounds].size.width - 40, 20)];
		[slider addTarget:self action:@selector(cellSliderChanged:) forControlEvents:UIControlEventValueChanged];
		[slider setMinimumValue:15];
		[slider setMaximumValue:500];
		[slider setValue:[_defaults floatForKey:@"sensitivity"]];
		[cell addSubview:slider];

	}

	return cell;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {

	if (section == 1) {
		return @"Ethan Arbuckle";
	}

	return @"";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	[tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)cellSwitchChanged:(UISwitch *)cellSwitch {
	[_defaults setBool:[cellSwitch isOn] forKey:@"isEnabled"];
	[_defaults synchronize];
}

- (void)cellSliderChanged:(UISlider *)slider {
	[_defaults setFloat:[slider value] forKey:@"sensitivity"];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)@"prefsUpdate", NULL, NULL, YES);

}

@end

@interface forcetouchactivator_prefsListController : PSListController
@end

@implementation forcetouchactivator_prefsListController

- (id)specifiers {

	return nil;
}

- (id)init {

	if (self = [super init]) {

		PrefsView *prefs = [[PrefsView alloc] init];
		[[self view] addSubview:prefs];

		[self setTitle:@"ForceTouchActivator"];

	}

	return self;
}

@end