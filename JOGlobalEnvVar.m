//
//  JOGlobalEnvVar.m
//  JOBridge
//
//  Created by Wei on 2018/12/12.
//  Copyright © 2018年 Wei. All rights reserved.
//

#if __arm64__

#import "JOGlobalEnvVar.h"
#import "JOObject.h"
#import <UIKit/UIKit.h>
#import "JOBridge.h"
#import <UserNotifications/UserNotifications.h>

static NSMutableDictionary *_JOGlobalEnvVars;

@implementation JOGlobalEnvVar

+ (void)load {
    [self registerPlugin];
}

+ (void)initPlugin {
    
    NSMutableDictionary *pluginStore = [self pluginStore];
    
    pluginStore[@"SCREEN_WIDTH"] = @([[UIScreen mainScreen] bounds].size.width);
    pluginStore[@"SCREEN_HEIGHT"] = @([[UIScreen mainScreen] bounds].size.height);
    pluginStore[@"SYS_VERSION"] = @([[[UIDevice currentDevice] systemVersion] doubleValue]);
    
    
    pluginStore[@"DISPATCH_SOURCE_TYPE_TIMER"] =  JOMakePointerObj((void *)DISPATCH_SOURCE_TYPE_TIMER);
    pluginStore[@"DISPATCH_QUEUE_CONCURRENT"] =  JOMakeObj(DISPATCH_QUEUE_CONCURRENT);
    pluginStore[@"DISPATCH_QUEUE_SERIAL"] = [NSNull null];;
    pluginStore[@"DISPATCH_TIME_FOREVER"] =  @(DISPATCH_TIME_FOREVER);
    pluginStore[@"DISPATCH_QUEUE_PRIORITY_BACKGROUND"] =  @(DISPATCH_QUEUE_PRIORITY_BACKGROUND);
    pluginStore[@"DISPATCH_QUEUE_PRIORITY_HIGH"] =  @(DISPATCH_QUEUE_PRIORITY_HIGH);
    pluginStore[@"DISPATCH_QUEUE_PRIORITY_DEFAULT"] =  @(DISPATCH_QUEUE_PRIORITY_DEFAULT);
    pluginStore[@"DISPATCH_QUEUE_PRIORITY_LOW"] =  @(DISPATCH_QUEUE_PRIORITY_LOW);
    pluginStore[@"NSEC_PER_SEC"] = @(NSEC_PER_SEC);
    
    pluginStore[@"RGB"] = ^(JSValue *jsvalue) {
        uint32_t hex = [jsvalue toUInt32] ;
        return JOGetObj([UIColor colorWithRed:(((hex & 0xFF0000) >> 16))/255.0 green:(((hex & 0xFF00) >> 8))/255.0 blue:((hex & 0xFF))/255.0 alpha:1.0]);
    };
    
    pluginStore[@"M_PI"] = @(M_PI);
    pluginStore[@"M_PI_2"] = @(M_PI_2);
    pluginStore[@"M_PI_4"] = @(M_PI_4);
    pluginStore[@"M_E"] = @(M_E);
    pluginStore[@"M_LOG2E"] = @(M_LOG2E);
    pluginStore[@"M_LOG10E"] = @(M_LOG10E);
    pluginStore[@"M_LN2"] = @(M_LN2);
    pluginStore[@"M_LN10"] = @(M_LN10);
    pluginStore[@"M_SQRT2"] = @(M_SQRT2);
    
    
    pluginStore[@"NSUTF8StringEncoding"] = @(NSUTF8StringEncoding);
    pluginStore[@"NSASCIIStringEncoding"] = @(NSASCIIStringEncoding);
    pluginStore[@"NSUnicodeStringEncoding"] = @(NSUnicodeStringEncoding);
    
    
    
    pluginStore[@"NSCalendarUnitEra"] = @(NSCalendarUnitEra);
    pluginStore[@"NSCalendarUnitYear"] = @(NSCalendarUnitYear);
    pluginStore[@"NSCalendarUnitMonth"] = @(NSCalendarUnitMonth);
    pluginStore[@"NSCalendarUnitDay"] = @(NSCalendarUnitDay);
    pluginStore[@"NSCalendarUnitHour"] = @(NSCalendarUnitHour);
    pluginStore[@"NSCalendarUnitMinute"] = @(NSCalendarUnitMinute);
    pluginStore[@"NSCalendarUnitSecond"] = @(NSCalendarUnitSecond);
    pluginStore[@"NSCalendarUnitWeekday"] = @(NSCalendarUnitWeekday);
    pluginStore[@"NSCalendarUnitQuarter"] = @(NSCalendarUnitQuarter);
    pluginStore[@"NSCalendarUnitCalendar"] = @(NSCalendarUnitCalendar);
    pluginStore[@"NSCalendarUnitWeekOfMonth"] = @(NSCalendarUnitWeekOfMonth);
    pluginStore[@"NSCalendarUnitWeekOfYear"] = @(NSCalendarUnitWeekOfYear);
    
    
    pluginStore[@"NSRoundPlain"] = @(NSRoundPlain);
    pluginStore[@"NSRoundDown"] = @(NSRoundDown);
    pluginStore[@"NSRoundUp"] = @(NSRoundUp);
    pluginStore[@"NSRoundBankers"] = @(NSRoundBankers);
    
    
    pluginStore[@"NSLocalizedDescriptionKey"] = NSLocalizedDescriptionKey;
    pluginStore[@"NSGenericException"] = NSGenericException;
    
    
    pluginStore[@"NSJSONReadingMutableContainers"] = @(NSJSONReadingMutableContainers);
    pluginStore[@"NSJSONReadingMutableLeaves"] = @(NSJSONReadingMutableLeaves);
    pluginStore[@"NSJSONReadingAllowFragments"] = @(NSJSONReadingAllowFragments);
    pluginStore[@"NSJSONWritingPrettyPrinted"] = @(NSJSONWritingPrettyPrinted);
    if (@available(iOS 11.0, *)) {
        pluginStore[@"NSJSONWritingSortedKeys"] = @(NSJSONWritingSortedKeys);
    }
    
    pluginStore[@"UIStatusBarStyleDefault"] = @(UIStatusBarStyleDefault);
    pluginStore[@"UIStatusBarStyleLightContent"] = @(UIStatusBarStyleLightContent);
    
    
    pluginStore[@"UIInterfaceOrientationUnknown"] = @(UIInterfaceOrientationUnknown);
    pluginStore[@"UIInterfaceOrientationPortrait"] = @(UIInterfaceOrientationPortrait);
    pluginStore[@"UIInterfaceOrientationPortraitUpsideDown"] = @(UIInterfaceOrientationPortraitUpsideDown);
    pluginStore[@"UIInterfaceOrientationLandscapeLeft"] = @(UIInterfaceOrientationLandscapeLeft);
    pluginStore[@"UIInterfaceOrientationLandscapeRight"] = @(UIInterfaceOrientationLandscapeRight);
    
    
    if (@available(iOS 10.0, *)) {
        pluginStore[@"UNAuthorizationOptionBadge"] = @(UNAuthorizationOptionBadge);
        pluginStore[@"UNAuthorizationOptionSound"] = @(UNAuthorizationOptionSound);
        pluginStore[@"UNAuthorizationOptionAlert"] = @(UNAuthorizationOptionAlert);
        pluginStore[@"UNAuthorizationOptionCarPlay"] = @(UNAuthorizationOptionCarPlay);
    }
    
    if (@available(iOS 12.0, *)) {
        pluginStore[@"UNAuthorizationOptionCriticalAlert"] = @(UNAuthorizationOptionCriticalAlert);
        pluginStore[@"UNAuthorizationOptionProvidesAppNotificationSettings"] = @(UNAuthorizationOptionProvidesAppNotificationSettings);
        pluginStore[@"UNAuthorizationOptionProvisional"] = @(UNAuthorizationOptionProvisional);
    }
    
    
    pluginStore[@"UIApplicationStateActive"] = @(UIApplicationStateActive);
    pluginStore[@"UIApplicationStateInactive"] = @(UIApplicationStateInactive);
    pluginStore[@"UIApplicationStateBackground"] = @(UIApplicationStateBackground);
    
    
    pluginStore[@"UIBackgroundTaskInvalid"] = @(UIBackgroundTaskInvalid);
    pluginStore[@"UIMinimumKeepAliveTimeout"] = @(UIMinimumKeepAliveTimeout);
    pluginStore[@"UIApplicationBackgroundFetchIntervalMinimum"] = @(UIApplicationBackgroundFetchIntervalMinimum);
    pluginStore[@"UIApplicationBackgroundFetchIntervalNever"] = @(UIApplicationBackgroundFetchIntervalNever);
    pluginStore[@"UIApplicationUserDidTakeScreenshotNotification"] = UIApplicationUserDidTakeScreenshotNotification;
    if (@available(iOS 8.0, *)) {
        pluginStore[@"UIApplicationOpenSettingsURLString"] = UIApplicationOpenSettingsURLString;
    }
    
    
    pluginStore[@"UIButtonTypeCustom"] = @(UIButtonTypeCustom);
    pluginStore[@"UIButtonTypeDetailDisclosure"] = @(UIButtonTypeDetailDisclosure);
    pluginStore[@"UIButtonTypeSystem"] = @(UIButtonTypeSystem);
    
    
    pluginStore[@"UICollectionViewScrollPositionNone"] = @(UICollectionViewScrollPositionNone);
    pluginStore[@"UICollectionViewScrollPositionTop"] = @(UICollectionViewScrollPositionTop);
    pluginStore[@"UICollectionViewScrollPositionCenteredVertically"] = @(UICollectionViewScrollPositionCenteredVertically);
    pluginStore[@"UICollectionViewScrollPositionBottom"] = @(UICollectionViewScrollPositionBottom);
    pluginStore[@"UICollectionViewScrollPositionLeft"] = @(UICollectionViewScrollPositionLeft);
    pluginStore[@"UICollectionViewScrollPositionCenteredHorizontally"] = @(UICollectionViewScrollPositionCenteredHorizontally);
    pluginStore[@"UICollectionViewScrollPositionRight"] = @(UICollectionViewScrollPositionRight);
    
    if (@available(iOS 11.0, *)) {
        pluginStore[@"UICollectionViewCellDragStateNone"] = @(UICollectionViewCellDragStateNone);
        pluginStore[@"UICollectionViewCellDragStateLifting"] = @(UICollectionViewCellDragStateLifting);
        pluginStore[@"UICollectionViewCellDragStateDragging"] = @(UICollectionViewCellDragStateDragging);
    }
    
    
    pluginStore[@"UICollectionElementKindSectionHeader"] = UICollectionElementKindSectionHeader;
    pluginStore[@"UICollectionElementKindSectionFooter"] = UICollectionElementKindSectionFooter;
    if (@available(iOS 10.0, *)) {
        pluginStore[@"UICollectionViewFlowLayoutAutomaticSize"] = @(UICollectionViewFlowLayoutAutomaticSize);
    }
    
    pluginStore[@"UICollectionViewScrollDirectionVertical"] = @(UICollectionViewScrollDirectionVertical);
    pluginStore[@"UICollectionViewScrollDirectionHorizontal"] = @(UICollectionViewScrollDirectionHorizontal);
    if (@available(iOS 11.0, *)) {
        pluginStore[@"UICollectionViewFlowLayoutSectionInsetFromContentInset"] = @(UICollectionViewFlowLayoutSectionInsetFromContentInset);
        pluginStore[@"UICollectionViewFlowLayoutSectionInsetFromSafeArea"] = @(UICollectionViewFlowLayoutSectionInsetFromSafeArea);
        pluginStore[@"UICollectionViewFlowLayoutSectionInsetFromLayoutMargins"] = @(UICollectionViewFlowLayoutSectionInsetFromLayoutMargins);
    }
    pluginStore[@"UICollectionUpdateActionInsert"] = @(UICollectionUpdateActionInsert);
    pluginStore[@"UICollectionUpdateActionDelete"] = @(UICollectionUpdateActionDelete);
    pluginStore[@"UICollectionUpdateActionReload"] = @(UICollectionUpdateActionReload);
    pluginStore[@"UICollectionUpdateActionMove"] = @(UICollectionUpdateActionMove);
    pluginStore[@"UICollectionUpdateActionNone"] = @(UICollectionUpdateActionNone);
    
    pluginStore[@"UICollectionElementCategoryCell"] = @(UICollectionElementCategoryCell);
    pluginStore[@"UICollectionElementCategorySupplementaryView"] = @(UICollectionElementCategorySupplementaryView);
    pluginStore[@"UICollectionElementCategoryDecorationView"] = @(UICollectionElementCategoryDecorationView);
    
    
    pluginStore[@"UIControlEventTouchDown"] = @(UIControlEventTouchDown);
    pluginStore[@"UIControlEventTouchDownRepeat"] = @(UIControlEventTouchDownRepeat);
    pluginStore[@"UIControlEventTouchDragInside"] = @(UIControlEventTouchDragInside);
    pluginStore[@"UIControlEventTouchDragOutside"] = @(UIControlEventTouchDragOutside);
    pluginStore[@"UIControlEventTouchDragEnter"] = @(UIControlEventTouchDragEnter);
    pluginStore[@"UIControlEventTouchDragExit"] = @(UIControlEventTouchDragExit);
    pluginStore[@"UIControlEventTouchUpInside"] = @(UIControlEventTouchUpInside);
    pluginStore[@"UIControlEventTouchUpOutside"] = @(UIControlEventTouchUpOutside);
    pluginStore[@"UIControlEventTouchCancel"] = @(UIControlEventTouchCancel);
    pluginStore[@"UIControlEventValueChanged"] = @(UIControlEventValueChanged);
    if (@available(iOS 9.0, *)) {
        pluginStore[@"UIControlEventPrimaryActionTriggered"] = @(UIControlEventPrimaryActionTriggered);
    }
    pluginStore[@"UIControlEventEditingDidBegin"] = @(UIControlEventEditingDidBegin);
    pluginStore[@"UIControlEventEditingChanged"] = @(UIControlEventEditingChanged);
    pluginStore[@"UIControlEventEditingDidEnd"] = @(UIControlEventEditingDidEnd);
    pluginStore[@"UIControlEventEditingDidEndOnExit"] = @(UIControlEventEditingDidEndOnExit);
    pluginStore[@"UIControlEventAllTouchEvents"] = @(UIControlEventAllTouchEvents);
    pluginStore[@"UIControlEventAllEditingEvents"] = @(UIControlEventAllEditingEvents);
    pluginStore[@"UIControlEventApplicationReserved"] = @(UIControlEventApplicationReserved);
    pluginStore[@"UIControlEventSystemReserved"] = @(UIControlEventSystemReserved);
    pluginStore[@"UIControlEventAllEvents"] = @(UIControlEventAllEvents);
    
    pluginStore[@"UIControlContentVerticalAlignmentCenter"] = @(UIControlContentVerticalAlignmentCenter);
    pluginStore[@"UIControlContentVerticalAlignmentTop"] = @(UIControlContentVerticalAlignmentTop);
    pluginStore[@"UIControlContentVerticalAlignmentBottom"] = @(UIControlContentVerticalAlignmentBottom);
    pluginStore[@"UIControlContentVerticalAlignmentFill"] = @(UIControlContentVerticalAlignmentFill);
    pluginStore[@"UIControlContentHorizontalAlignmentCenter"] = @(UIControlContentHorizontalAlignmentCenter);
    pluginStore[@"UIControlContentHorizontalAlignmentLeft"] = @(UIControlContentHorizontalAlignmentLeft);
    pluginStore[@"UIControlContentHorizontalAlignmentRight"] = @(UIControlContentHorizontalAlignmentRight);
    pluginStore[@"UIControlContentHorizontalAlignmentFill"] = @(UIControlContentHorizontalAlignmentFill);
    if (@available(iOS 11.0, *)) {
        pluginStore[@"UIControlContentHorizontalAlignmentLeading"] = @(UIControlContentHorizontalAlignmentLeading);
        pluginStore[@"UIControlContentHorizontalAlignmentTrailing"] = @(UIControlContentHorizontalAlignmentTrailing);
    }
    pluginStore[@"UIControlStateNormal"] = @(UIControlStateNormal);
    pluginStore[@"UIControlStateHighlighted"] = @(UIControlStateHighlighted);
    pluginStore[@"UIControlStateDisabled"] = @(UIControlStateDisabled);
    pluginStore[@"UIControlStateSelected"] = @(UIControlStateSelected);
    if (@available(iOS 9.0, *)) {
        pluginStore[@"UIControlStateFocused"] = @(UIControlStateFocused);
    }
    
    
    pluginStore[@"UIDatePickerModeTime"] = @(UIDatePickerModeTime);
    pluginStore[@"UIDatePickerModeDate"] = @(UIDatePickerModeDate);
    pluginStore[@"UIDatePickerModeDateAndTime"] = @(UIDatePickerModeDateAndTime);
    pluginStore[@"UIDatePickerModeCountDownTimer"] = @(UIDatePickerModeCountDownTimer);
    
    pluginStore[@"UIDeviceOrientationUnknown"] = @(UIDeviceOrientationUnknown);
    pluginStore[@"UIDeviceOrientationPortrait"] = @(UIDeviceOrientationPortrait);
    pluginStore[@"UIDeviceOrientationPortraitUpsideDown"] = @(UIDeviceOrientationPortraitUpsideDown);
    pluginStore[@"UIDeviceOrientationLandscapeLeft"] = @(UIDeviceOrientationLandscapeLeft);
    pluginStore[@"UIDeviceOrientationLandscapeRight"] = @(UIDeviceOrientationLandscapeRight);
    pluginStore[@"UIDeviceOrientationFaceUp"] = @(UIDeviceOrientationFaceUp);
    pluginStore[@"UIDeviceOrientationFaceDown"] = @(UIDeviceOrientationFaceDown);
    
    pluginStore[@"UIDeviceBatteryStateUnknown"] = @(UIDeviceBatteryStateUnknown);
    pluginStore[@"UIDeviceBatteryStateUnplugged"] = @(UIDeviceBatteryStateUnplugged);
    pluginStore[@"UIDeviceBatteryStateCharging"] = @(UIDeviceBatteryStateCharging);
    pluginStore[@"UIDeviceBatteryStateFull"] = @(UIDeviceBatteryStateFull);
    
    pluginStore[@"UIUserInterfaceIdiomUnspecified"] = @(UIUserInterfaceIdiomUnspecified);
    pluginStore[@"UIUserInterfaceIdiomPhone"] = @(UIUserInterfaceIdiomPhone);
    pluginStore[@"UIUserInterfaceIdiomPad"] = @(UIUserInterfaceIdiomPad);
    
    pluginStore[@"UIDeviceOrientationDidChangeNotification"] = UIDeviceOrientationDidChangeNotification;
    pluginStore[@"UIDeviceBatteryStateDidChangeNotification"] = UIDeviceBatteryStateDidChangeNotification;
    pluginStore[@"UIDeviceBatteryLevelDidChangeNotification"] = UIDeviceBatteryLevelDidChangeNotification;
    pluginStore[@"UIDeviceProximityStateDidChangeNotification"] = UIDeviceProximityStateDidChangeNotification;
    
    
    pluginStore[@"UIRectEdgeNone"] = @(UIRectEdgeNone);
    pluginStore[@"UIRectEdgeTop"] = @(UIRectEdgeTop);
    pluginStore[@"UIRectEdgeLeft"] = @(UIRectEdgeLeft);
    pluginStore[@"UIRectEdgeBottom"] = @(UIRectEdgeBottom);
    pluginStore[@"UIRectEdgeRight"] = @(UIRectEdgeRight);
    pluginStore[@"UIRectEdgeAll"] = @(UIRectEdgeAll);
    
    pluginStore[@"UIGestureRecognizerStatePossible"] = @(UIGestureRecognizerStatePossible);
    pluginStore[@"UIGestureRecognizerStateBegan"] = @(UIGestureRecognizerStateBegan);
    pluginStore[@"UIGestureRecognizerStateChanged"] = @(UIGestureRecognizerStateChanged);
    pluginStore[@"UIGestureRecognizerStateEnded"] = @(UIGestureRecognizerStateEnded);
    pluginStore[@"UIGestureRecognizerStateCancelled"] = @(UIGestureRecognizerStateCancelled);
    pluginStore[@"UIGestureRecognizerStateFailed"] = @(UIGestureRecognizerStateFailed);
    pluginStore[@"UIGestureRecognizerStateRecognized"] = @(UIGestureRecognizerStateRecognized);
    
    
    pluginStore[@"UINavigationControllerOperationNone"] = @(UINavigationControllerOperationNone);
    pluginStore[@"UINavigationControllerOperationPush"] = @(UINavigationControllerOperationPush);
    pluginStore[@"UINavigationControllerOperationPop"] = @(UINavigationControllerOperationPop);
    pluginStore[@"UINavigationControllerHideShowBarDuration"] = @(UINavigationControllerHideShowBarDuration);
    
    
    pluginStore[@"UIBarMetricsDefault"] = @(UIBarMetricsDefault);
    pluginStore[@"UIBarMetricsCompact"] = @(UIBarMetricsCompact);
    pluginStore[@"UIBarMetricsDefaultPrompt"] = @(UIBarMetricsDefaultPrompt);
    pluginStore[@"UIBarMetricsCompactPrompt"] = @(UIBarMetricsCompactPrompt);
    
    pluginStore[@"UIBarPositionAny"] = @(UIBarPositionAny);
    pluginStore[@"UIBarPositionBottom"] = @(UIBarPositionBottom);
    pluginStore[@"UIBarPositionTop"] = @(UIBarPositionTop);
    pluginStore[@"UIBarPositionTopAttached"] = @(UIBarPositionTopAttached);
    
    
    pluginStore[@"UIScreenDidConnectNotification"] = UIScreenDidConnectNotification;
    pluginStore[@"UIScreenDidDisconnectNotification"] = UIScreenDidDisconnectNotification;
    pluginStore[@"UIScreenModeDidChangeNotification"] = UIScreenModeDidChangeNotification;
    pluginStore[@"UIScreenBrightnessDidChangeNotification"] = UIScreenBrightnessDidChangeNotification;
    
    
    pluginStore[@"UIScrollViewKeyboardDismissModeNone"] = @(UIScrollViewKeyboardDismissModeNone);
    pluginStore[@"UIScrollViewKeyboardDismissModeOnDrag"] = @(UIScrollViewKeyboardDismissModeOnDrag);
    pluginStore[@"UIScrollViewKeyboardDismissModeInteractive"] = @(UIScrollViewKeyboardDismissModeInteractive);
    pluginStore[@"UIScrollViewIndexDisplayModeAutomatic"] = @(UIScrollViewIndexDisplayModeAutomatic);
    pluginStore[@"UIScrollViewIndexDisplayModeAlwaysHidden"] = @(UIScrollViewIndexDisplayModeAlwaysHidden);
    
    
    if (@available(iOS 11.0, *)) {
        pluginStore[@"UIScrollViewContentInsetAdjustmentAutomatic"] = @(UIScrollViewContentInsetAdjustmentAutomatic);
        pluginStore[@"UIScrollViewContentInsetAdjustmentScrollableAxes"] = @(UIScrollViewContentInsetAdjustmentScrollableAxes);
        pluginStore[@"UIScrollViewContentInsetAdjustmentNever"] = @(UIScrollViewContentInsetAdjustmentNever);
        pluginStore[@"UIScrollViewContentInsetAdjustmentAlways"] = @(UIScrollViewContentInsetAdjustmentAlways);
    }
    
    
    pluginStore[@"UIScrollViewDecelerationRateNormal"] = @(UIScrollViewDecelerationRateNormal);
    pluginStore[@"UIScrollViewDecelerationRateFast"] = @(UIScrollViewDecelerationRateFast);
    
    
    
    pluginStore[@"UITableViewStylePlain"] = @(UITableViewStylePlain);
    pluginStore[@"UITableViewStyleGrouped"] = @(UITableViewStyleGrouped);
    pluginStore[@"UITableViewScrollPositionNone"] = @(UITableViewScrollPositionNone);
    pluginStore[@"UITableViewScrollPositionTop"] = @(UITableViewScrollPositionTop);
    pluginStore[@"UITableViewScrollPositionMiddle"] = @(UITableViewScrollPositionMiddle);
    pluginStore[@"UITableViewScrollPositionBottom"] = @(UITableViewScrollPositionBottom);
    
    pluginStore[@"UITableViewRowAnimationFade"] = @(UITableViewRowAnimationFade);
    pluginStore[@"UITableViewRowAnimationRight"] = @(UITableViewRowAnimationRight);
    pluginStore[@"UITableViewRowAnimationLeft"] = @(UITableViewRowAnimationLeft);
    pluginStore[@"UITableViewRowAnimationTop"] = @(UITableViewRowAnimationTop);
    pluginStore[@"UITableViewRowAnimationBottom"] = @(UITableViewRowAnimationBottom);
    pluginStore[@"UITableViewRowAnimationNone"] = @(UITableViewRowAnimationNone);
    pluginStore[@"UITableViewRowAnimationMiddle"] = @(UITableViewRowAnimationMiddle);
    pluginStore[@"UITableViewRowAnimationAutomatic"] = @(UITableViewRowAnimationAutomatic);
    
    pluginStore[@"UITableViewIndexSearch"] = UITableViewIndexSearch;
    pluginStore[@"UITableViewAutomaticDimension"] = @(UITableViewAutomaticDimension);
    
    
    if (@available(iOS 8.0, *)) {
        pluginStore[@"UITableViewRowActionStyleDefault"] = @(UITableViewRowActionStyleDefault);
        pluginStore[@"UITableViewRowActionStyleDestructive"] = @(UITableViewRowActionStyleDestructive);
        pluginStore[@"UITableViewRowActionStyleNormal"] = @(UITableViewRowActionStyleNormal);
        
    }
    pluginStore[@"UITableViewCellStyleDefault"] = @(UITableViewCellStyleDefault);
    pluginStore[@"UITableViewCellStyleValue1"] = @(UITableViewCellStyleValue1);
    pluginStore[@"UITableViewCellStyleValue2"] = @(UITableViewCellStyleValue2);
    pluginStore[@"UITableViewCellStyleSubtitle"] = @(UITableViewCellStyleSubtitle);
    
    pluginStore[@"UITableViewCellSeparatorStyleNone"] = @(UITableViewCellSeparatorStyleNone);
    pluginStore[@"UITableViewCellSeparatorStyleSingleLine"] = @(UITableViewCellSeparatorStyleSingleLine);
    pluginStore[@"UITableViewCellSeparatorStyleSingleLineEtched"] = @(UITableViewCellSeparatorStyleSingleLineEtched);
    
    pluginStore[@"UITableViewCellSelectionStyleNone"] = @(UITableViewCellSelectionStyleNone);
    pluginStore[@"UITableViewCellSelectionStyleBlue"] = @(UITableViewCellSelectionStyleBlue);
    pluginStore[@"UITableViewCellSelectionStyleGray"] = @(UITableViewCellSelectionStyleGray);
    pluginStore[@"UITableViewCellSelectionStyleDefault"] = @(UITableViewCellSelectionStyleDefault);
    
    if (@available(iOS 9.0, *)) {
        pluginStore[@"UITableViewCellFocusStyleDefault"] = @(UITableViewCellFocusStyleDefault);
        pluginStore[@"UITableViewCellFocusStyleCustom"] = @(UITableViewCellFocusStyleCustom);
    }
    
    pluginStore[@"UITableViewCellEditingStyleNone"] = @(UITableViewCellEditingStyleNone);
    pluginStore[@"UITableViewCellEditingStyleDelete"] = @(UITableViewCellEditingStyleDelete);
    pluginStore[@"UITableViewCellEditingStyleInsert"] = @(UITableViewCellEditingStyleInsert);
    
    pluginStore[@"UITableViewCellAccessoryNone"] = @(UITableViewCellAccessoryNone);
    pluginStore[@"UITableViewCellAccessoryDisclosureIndicator"] = @(UITableViewCellAccessoryDisclosureIndicator);
    pluginStore[@"UITableViewCellAccessoryDetailDisclosureButton"] = @(UITableViewCellAccessoryDetailDisclosureButton);
    pluginStore[@"UITableViewCellAccessoryCheckmark"] = @(UITableViewCellAccessoryCheckmark);
    pluginStore[@"UITableViewCellAccessoryDetailButton"] = @(UITableViewCellAccessoryDetailButton);
    
    
    pluginStore[@"UITextBorderStyleNone"] = @(UITextBorderStyleNone);
    pluginStore[@"UITextBorderStyleLine"] = @(UITextBorderStyleLine);
    pluginStore[@"UITextBorderStyleBezel"] = @(UITextBorderStyleBezel);
    pluginStore[@"UITextBorderStyleRoundedRect"] = @(UITextBorderStyleRoundedRect);
    
    pluginStore[@"UITextFieldViewModeNever"] = @(UITextFieldViewModeNever);
    pluginStore[@"UITextFieldViewModeWhileEditing"] = @(UITextFieldViewModeWhileEditing);
    pluginStore[@"UITextFieldViewModeUnlessEditing"] = @(UITextFieldViewModeUnlessEditing);
    pluginStore[@"UITextFieldViewModeAlways"] = @(UITextFieldViewModeAlways);
    
    pluginStore[@"UITextFieldTextDidBeginEditingNotification"] = UITextFieldTextDidBeginEditingNotification;
    pluginStore[@"UITextFieldTextDidEndEditingNotification"] = UITextFieldTextDidEndEditingNotification;
    pluginStore[@"UITextFieldTextDidChangeNotification"] = UITextFieldTextDidChangeNotification;
    if (@available(iOS 10.0, *)) {
        pluginStore[@"UITextFieldDidEndEditingReasonKey"] = UITextFieldDidEndEditingReasonKey;
    }
    pluginStore[@"UITextStorageDirectionForward"] = @(UITextStorageDirectionForward);
    pluginStore[@"UITextStorageDirectionBackward"] = @(UITextStorageDirectionBackward);
    pluginStore[@"UITextLayoutDirectionRight"] = @(UITextLayoutDirectionRight);
    pluginStore[@"UITextLayoutDirectionLeft"] = @(UITextLayoutDirectionLeft);
    pluginStore[@"UITextLayoutDirectionUp"] = @(UITextLayoutDirectionUp);
    pluginStore[@"UITextLayoutDirectionDown"] = @(UITextLayoutDirectionDown);
    
    pluginStore[@"UITextWritingDirectionNatural"] = @(UITextWritingDirectionNatural);
    pluginStore[@"UITextWritingDirectionLeftToRight"] = @(UITextWritingDirectionLeftToRight);
    pluginStore[@"UITextWritingDirectionRightToLeft"] = @(UITextWritingDirectionRightToLeft);
    
    pluginStore[@"UITextGranularityCharacter"] = @(UITextGranularityCharacter);
    pluginStore[@"UITextGranularityWord"] = @(UITextGranularityWord);
    pluginStore[@"UITextGranularitySentence"] = @(UITextGranularitySentence);
    pluginStore[@"UITextGranularityParagraph"] = @(UITextGranularityParagraph);
    pluginStore[@"UITextGranularityLine"] = @(UITextGranularityLine);
    pluginStore[@"UITextGranularityDocument"] = @(UITextGranularityDocument);
    
    pluginStore[@"UITextViewTextDidBeginEditingNotification"] = UITextViewTextDidBeginEditingNotification;
    pluginStore[@"UITextViewTextDidChangeNotification"] = UITextViewTextDidChangeNotification;
    pluginStore[@"UITextViewTextDidEndEditingNotification"] = UITextViewTextDidEndEditingNotification;
    
    
    pluginStore[@"UIViewAnimationCurveEaseInOut"] = @(UIViewAnimationCurveEaseInOut);
    pluginStore[@"UIViewAnimationCurveEaseIn"] = @(UIViewAnimationCurveEaseIn);
    pluginStore[@"UIViewAnimationCurveEaseOut"] = @(UIViewAnimationCurveEaseOut);
    pluginStore[@"UIViewAnimationCurveLinear"] = @(UIViewAnimationCurveLinear);
    
    pluginStore[@"UIViewContentModeScaleToFill"] = @(UIViewContentModeScaleToFill);
    pluginStore[@"UIViewContentModeScaleAspectFit"] = @(UIViewContentModeScaleAspectFit);
    pluginStore[@"UIViewContentModeScaleAspectFill"] = @(UIViewContentModeScaleAspectFill);
    pluginStore[@"UIViewContentModeRedraw"] = @(UIViewContentModeRedraw);
    pluginStore[@"UIViewContentModeCenter"] = @(UIViewContentModeCenter);
    pluginStore[@"UIViewContentModeTop"] = @(UIViewContentModeTop);
    pluginStore[@"UIViewContentModeBottom"] = @(UIViewContentModeBottom);
    pluginStore[@"UIViewContentModeLeft"] = @(UIViewContentModeLeft);
    pluginStore[@"UIViewContentModeRight"] = @(UIViewContentModeRight);
    pluginStore[@"UIViewContentModeTopRight"] = @(UIViewContentModeTopRight);
    pluginStore[@"UIViewContentModeTopLeft"] = @(UIViewContentModeTopLeft);
    pluginStore[@"UIViewContentModeBottomLeft"] = @(UIViewContentModeBottomLeft);
    pluginStore[@"UIViewContentModeBottomRight"] = @(UIViewContentModeBottomRight);
    
    
    pluginStore[@"UIViewAnimationTransitionNone"] = @(UIViewAnimationTransitionNone);
    pluginStore[@"UIViewAnimationTransitionFlipFromLeft"] = @(UIViewAnimationTransitionFlipFromLeft);
    pluginStore[@"UIViewAnimationTransitionFlipFromRight"] = @(UIViewAnimationTransitionFlipFromRight);
    pluginStore[@"UIViewAnimationTransitionCurlUp"] = @(UIViewAnimationTransitionCurlUp);
    pluginStore[@"UIViewAnimationTransitionCurlDown"] = @(UIViewAnimationTransitionCurlDown);
    
    pluginStore[@"UIViewAutoresizingNone"] = @(UIViewAutoresizingNone);
    pluginStore[@"UIViewAutoresizingFlexibleLeftMargin"] = @(UIViewAutoresizingFlexibleLeftMargin);
    pluginStore[@"UIViewAutoresizingFlexibleWidth"] = @(UIViewAutoresizingFlexibleWidth);
    pluginStore[@"UIViewAutoresizingFlexibleRightMargin"] = @(UIViewAutoresizingFlexibleRightMargin);
    pluginStore[@"UIViewAutoresizingFlexibleTopMargin"] = @(UIViewAutoresizingFlexibleTopMargin);
    pluginStore[@"UIViewAutoresizingFlexibleHeight"] = @(UIViewAutoresizingFlexibleHeight);
    pluginStore[@"UIViewAutoresizingFlexibleBottomMargin"] = @(UIViewAutoresizingFlexibleBottomMargin);
    
    pluginStore[@"UIViewAnimationOptionLayoutSubviews"] = @(UIViewAnimationOptionLayoutSubviews);
    pluginStore[@"UIViewAnimationOptionAllowUserInteraction"] = @(UIViewAnimationOptionAllowUserInteraction);
    pluginStore[@"UIViewAnimationOptionBeginFromCurrentState"] = @(UIViewAnimationOptionBeginFromCurrentState);
    pluginStore[@"UIViewAnimationOptionRepeat"] = @(UIViewAnimationOptionRepeat);
    pluginStore[@"UIViewAnimationOptionAutoreverse"] = @(UIViewAnimationOptionAutoreverse);
    pluginStore[@"UIViewAnimationOptionOverrideInheritedDuration"] = @(UIViewAnimationOptionOverrideInheritedDuration);
    pluginStore[@"UIViewAnimationOptionOverrideInheritedCurve"] = @(UIViewAnimationOptionOverrideInheritedCurve);
    pluginStore[@"UIViewAnimationOptionAllowAnimatedContent"] = @(UIViewAnimationOptionAllowAnimatedContent);
    pluginStore[@"UIViewAnimationOptionShowHideTransitionViews"] = @(UIViewAnimationOptionShowHideTransitionViews);
    pluginStore[@"UIViewAnimationOptionOverrideInheritedOptions"] = @(UIViewAnimationOptionOverrideInheritedOptions);
    pluginStore[@"UIViewAnimationOptionCurveEaseInOut"] = @(UIViewAnimationOptionCurveEaseInOut);
    pluginStore[@"UIViewAnimationOptionCurveEaseIn"] = @(UIViewAnimationOptionCurveEaseIn);
    pluginStore[@"UIViewAnimationOptionCurveEaseOut"] = @(UIViewAnimationOptionCurveEaseOut);
    pluginStore[@"UIViewAnimationOptionCurveLinear"] = @(UIViewAnimationOptionCurveLinear);
    pluginStore[@"UIViewAnimationOptionTransitionNone"] = @(UIViewAnimationOptionTransitionNone);
    pluginStore[@"UIViewAnimationOptionTransitionFlipFromLeft"] = @(UIViewAnimationOptionTransitionFlipFromLeft);
    pluginStore[@"UIViewAnimationOptionTransitionFlipFromRight"] = @(UIViewAnimationOptionTransitionFlipFromRight);
    pluginStore[@"UIViewAnimationOptionTransitionCurlUp"] = @(UIViewAnimationOptionTransitionCurlUp);
    pluginStore[@"UIViewAnimationOptionTransitionCurlDown"] = @(UIViewAnimationOptionTransitionCurlDown);
    pluginStore[@"UIViewAnimationOptionTransitionCrossDissolve"] = @(UIViewAnimationOptionTransitionCrossDissolve);
    pluginStore[@"UIViewAnimationOptionTransitionFlipFromTop"] = @(UIViewAnimationOptionTransitionFlipFromTop);
    pluginStore[@"UIViewAnimationOptionTransitionFlipFromBottom"] = @(UIViewAnimationOptionTransitionFlipFromBottom);
    
    pluginStore[@"UIViewKeyframeAnimationOptionLayoutSubviews"] = @(UIViewKeyframeAnimationOptionLayoutSubviews);
    pluginStore[@"UIViewKeyframeAnimationOptionAllowUserInteraction"] = @(UIViewKeyframeAnimationOptionAllowUserInteraction);
    pluginStore[@"UIViewKeyframeAnimationOptionBeginFromCurrentState"] = @(UIViewKeyframeAnimationOptionBeginFromCurrentState);
    pluginStore[@"UIViewKeyframeAnimationOptionRepeat"] = @(UIViewKeyframeAnimationOptionRepeat);
    pluginStore[@"UIViewKeyframeAnimationOptionAutoreverse"] = @(UIViewKeyframeAnimationOptionAutoreverse);
    pluginStore[@"UIViewKeyframeAnimationOptionOverrideInheritedDuration"] = @(UIViewKeyframeAnimationOptionOverrideInheritedDuration);
    pluginStore[@"UIViewKeyframeAnimationOptionOverrideInheritedOptions"] = @(UIViewKeyframeAnimationOptionOverrideInheritedOptions);
    pluginStore[@"UIViewKeyframeAnimationOptionCalculationModeLinear"] = @(UIViewKeyframeAnimationOptionCalculationModeLinear);
    pluginStore[@"UIViewKeyframeAnimationOptionCalculationModeDiscrete"] = @(UIViewKeyframeAnimationOptionCalculationModeDiscrete);
    pluginStore[@"UIViewKeyframeAnimationOptionCalculationModePaced"] = @(UIViewKeyframeAnimationOptionCalculationModePaced);
    pluginStore[@"UIViewKeyframeAnimationOptionCalculationModeCubic"] = @(UIViewKeyframeAnimationOptionCalculationModeCubic);
    pluginStore[@"UIViewKeyframeAnimationOptionCalculationModeCubicPaced"] = @(UIViewKeyframeAnimationOptionCalculationModeCubicPaced);
    
    
    pluginStore[@"UIModalTransitionStyleCoverVertical"] = @(UIModalTransitionStyleCoverVertical);
    pluginStore[@"UIModalTransitionStyleFlipHorizontal"] = @(UIModalTransitionStyleFlipHorizontal);
    pluginStore[@"UIModalTransitionStyleCrossDissolve"] = @(UIModalTransitionStyleCrossDissolve);
    pluginStore[@"UIModalTransitionStylePartialCurl"] = @(UIModalTransitionStylePartialCurl);
    
    pluginStore[@"UIModalPresentationFullScreen"] = @(UIModalPresentationFullScreen);
    pluginStore[@"UIModalPresentationPageSheet"] = @(UIModalPresentationPageSheet);
    pluginStore[@"UIModalPresentationFormSheet"] = @(UIModalPresentationFormSheet);
    pluginStore[@"UIModalPresentationCurrentContext"] = @(UIModalPresentationCurrentContext);
    pluginStore[@"UIModalPresentationCustom"] = @(UIModalPresentationCustom);
    if (@available(iOS 8.0, *)) {
        pluginStore[@"UIModalPresentationOverFullScreen"] = @(UIModalPresentationOverFullScreen);
        pluginStore[@"UIModalPresentationOverCurrentContext"] = @(UIModalPresentationOverCurrentContext);
        pluginStore[@"UIModalPresentationPopover"] = @(UIModalPresentationPopover);
    }
    
    pluginStore[@"UIModalPresentationNone"] = @(UIModalPresentationNone);
    
    
    pluginStore[@"UIWindowLevelNormal"] = @(UIWindowLevelNormal);
    pluginStore[@"UIWindowLevelAlert"] = @(UIWindowLevelAlert);
    pluginStore[@"UIWindowLevelStatusBar"] = @(UIWindowLevelStatusBar);
    
    pluginStore[@"UIWindowDidBecomeVisibleNotification"] = UIWindowDidBecomeVisibleNotification;
    pluginStore[@"UIWindowDidBecomeHiddenNotification"] = UIWindowDidBecomeHiddenNotification;
    pluginStore[@"UIWindowDidBecomeKeyNotification"] = UIWindowDidBecomeKeyNotification;
    pluginStore[@"UIWindowDidResignKeyNotification"] = UIWindowDidResignKeyNotification;
    
    pluginStore[@"UIKeyboardWillShowNotification"] = UIKeyboardWillShowNotification;
    pluginStore[@"UIKeyboardDidShowNotification"] = UIKeyboardDidShowNotification;
    pluginStore[@"UIKeyboardWillHideNotification"] = UIKeyboardWillHideNotification;
    pluginStore[@"UIKeyboardDidHideNotification"] = UIKeyboardDidHideNotification;
    
    pluginStore[@"UIKeyboardFrameBeginUserInfoKey"] = UIKeyboardFrameBeginUserInfoKey;
    pluginStore[@"UIKeyboardFrameEndUserInfoKey"] = UIKeyboardFrameEndUserInfoKey;
    pluginStore[@"UIKeyboardAnimationDurationUserInfoKey"] = UIKeyboardAnimationDurationUserInfoKey;
    pluginStore[@"UIKeyboardAnimationCurveUserInfoKey"] = UIKeyboardAnimationCurveUserInfoKey;
    
    pluginStore[@"UIKeyboardWillChangeFrameNotification"] = UIKeyboardWillChangeFrameNotification;
    pluginStore[@"UIKeyboardDidChangeFrameNotification"] = UIKeyboardDidChangeFrameNotification;
    
    
    pluginStore[@"NSFontAttributeName"] = NSFontAttributeName;
    pluginStore[@"NSParagraphStyleAttributeName"] = NSParagraphStyleAttributeName;
    pluginStore[@"NSForegroundColorAttributeName"] = NSForegroundColorAttributeName;
    pluginStore[@"NSBackgroundColorAttributeName"] = NSBackgroundColorAttributeName;
    pluginStore[@"NSLigatureAttributeName"] = NSLigatureAttributeName;
    pluginStore[@"NSKernAttributeName"] = NSKernAttributeName;
    pluginStore[@"NSStrikethroughStyleAttributeName"] = NSStrikethroughStyleAttributeName;
    pluginStore[@"NSUnderlineStyleAttributeName"] = NSUnderlineStyleAttributeName;
    pluginStore[@"NSStrokeColorAttributeName"] = NSStrokeColorAttributeName;
    pluginStore[@"NSStrokeWidthAttributeName"] = NSStrokeWidthAttributeName;
    pluginStore[@"NSShadowAttributeName"] = NSShadowAttributeName;
    pluginStore[@"NSTextEffectAttributeName"] = NSTextEffectAttributeName;
    pluginStore[@"NSAttachmentAttributeName"] = NSAttachmentAttributeName;
    pluginStore[@"NSLinkAttributeName"] = NSLinkAttributeName;
    pluginStore[@"NSBaselineOffsetAttributeName"] = NSBaselineOffsetAttributeName;
    pluginStore[@"NSUnderlineColorAttributeName"] = NSUnderlineColorAttributeName;
    pluginStore[@"NSStrikethroughColorAttributeName"] = NSStrikethroughColorAttributeName;
    pluginStore[@"NSObliquenessAttributeName"] = NSObliquenessAttributeName;
    pluginStore[@"NSExpansionAttributeName"] = NSExpansionAttributeName;
    pluginStore[@"NSWritingDirectionAttributeName"] = NSWritingDirectionAttributeName;
    pluginStore[@"NSVerticalGlyphFormAttributeName"] = NSVerticalGlyphFormAttributeName;
    
    
    pluginStore[@"NSUnderlineStyleNone"] = @(NSUnderlineStyleNone);
    pluginStore[@"NSUnderlineStyleSingle"] = @(NSUnderlineStyleSingle);
    pluginStore[@"NSUnderlineStyleThick"] = @(NSUnderlineStyleThick);
    pluginStore[@"NSUnderlineStyleDouble"] = @(NSUnderlineStyleDouble);
    pluginStore[@"NSUnderlineStylePatternSolid"] = @(NSUnderlineStylePatternSolid);
    pluginStore[@"NSUnderlineStylePatternDot"] = @(NSUnderlineStylePatternDot);
    pluginStore[@"NSUnderlineStylePatternDash"] = @(NSUnderlineStylePatternDash);
    pluginStore[@"NSUnderlineStylePatternDashDot"] = @(NSUnderlineStylePatternDashDot);
    pluginStore[@"NSUnderlineStylePatternDashDotDot"] = @(NSUnderlineStylePatternDashDotDot);
    pluginStore[@"NSUnderlineStyleByWord"] = @(NSUnderlineStyleByWord);
    
    [self registerObject:pluginStore name:@"JOG" needTransform:NO];
}

+ (NSMutableDictionary *)pluginStore {
    if (!_JOGlobalEnvVars) {
        _JOGlobalEnvVars = [NSMutableDictionary dictionary];
    }
    return _JOGlobalEnvVars;
}
@end
#endif
