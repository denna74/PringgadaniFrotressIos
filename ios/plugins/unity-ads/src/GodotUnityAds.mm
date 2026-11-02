// GodotUnityAds.mm
//
// Bridges the Unity Ads iOS SDK to Godot as the `GodotUnityAds` native
// singleton. All Unity Ads delegate callbacks are routed to the main thread
// before signals are emitted, matching Godot's requirement that Object
// signals fire on the main thread.

#import "GodotUnityAds.h"
#import <UIKit/UIKit.h>
#import <UnityAds/UnityAds.h>
#import <UnityAds/UnityAds-Swift.h>
#include "core/config/engine.h"

GodotUnityAdsBridge *GodotUnityAdsBridge::instance = NULL;

// ---------------------------------------------------------------------------
// Objective-C delegate. Receives Unity Ads callbacks on arbitrary threads and
// forwards them to the C++ bridge on the main thread.
// ---------------------------------------------------------------------------
@implementation GodotUnityAds

- (void)initializationComplete {
    dispatch_async(dispatch_get_main_queue(), ^{
        GodotUnityAdsBridge::get_singleton()->emit_initialized();
    });
}

- (void)initializationFailed:(UnityAdsInitializationError)error withMessage:(NSString *)message {
    NSString *err = [NSString stringWithFormat:@"%ld", (long)error];
    dispatch_async(dispatch_get_main_queue(), ^{
        GodotUnityAdsBridge::get_singleton()->emit_init_failed([err UTF8String], [message UTF8String]);
    });
}

// UnityAdsLoadDelegate
- (void)unityAdsAdLoaded:(NSString *)placementId {
    dispatch_async(dispatch_get_main_queue(), ^{
        GodotUnityAdsBridge::get_singleton()->emit_ad_loaded([placementId UTF8String]);
    });
}

- (void)unityAdsAdFailedToLoad:(NSString *)placementId withError:(UnityAdsLoadError)error withMessage:(NSString *)message {
    NSString *err = [NSString stringWithFormat:@"%ld", (long)error];
    dispatch_async(dispatch_get_main_queue(), ^{
        GodotUnityAdsBridge::get_singleton()->emit_ad_load_failed([placementId UTF8String], [err UTF8String], [message UTF8String]);
    });
}

// UnityAdsShowDelegate
- (void)unityAdsShowStart:(NSString *)placementId {
    // No-op: ad presentation started.
}

- (void)unityAdsShowClick:(NSString *)placementId {
    // No-op: click reporting is not used by the rewarded flow.
}

- (void)unityAdsShowComplete:(NSString *)placementId withFinishState:(UnityAdsShowCompletionState)state {
    NSString *stateString;
    switch (state) {
        case kUnityShowCompletionStateCompleted: stateString = @"COMPLETED"; break;
        case kUnityShowCompletionStateSkipped:   stateString = @"SKIPPED";   break;
        default:                                 stateString = @"ERROR";     break;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        GodotUnityAdsBridge::get_singleton()->emit_ad_completed([placementId UTF8String], [stateString UTF8String]);
        if (state == kUnityShowCompletionStateCompleted) {
            GodotUnityAdsBridge::get_singleton()->emit_rewarded([placementId UTF8String]);
        }
    });
}

- (void)unityAdsShowFailed:(NSString *)placementId withError:(UnityAdsShowError)error withMessage:(NSString *)message {
    NSString *err = [NSString stringWithFormat:@"%ld", (long)error];
    dispatch_async(dispatch_get_main_queue(), ^{
        GodotUnityAdsBridge::get_singleton()->emit_ad_show_failed([placementId UTF8String], [err UTF8String], [message UTF8String]);
    });
}

@end

// ---------------------------------------------------------------------------
// Godot C++ bridge
// ---------------------------------------------------------------------------
GodotUnityAdsBridge::GodotUnityAdsBridge() {
    ERR_FAIL_COND(instance != NULL);
    instance = this;
    unityAds = [[GodotUnityAds alloc] init];
}

GodotUnityAdsBridge::~GodotUnityAdsBridge() {
    if (instance == this) {
        instance = NULL;
    }
    unityAds = nil;
}

GodotUnityAdsBridge *GodotUnityAdsBridge::get_singleton() {
    return instance;
}

bool GodotUnityAdsBridge::is_available() {
    return [UnityServices isInitialized];
}

void GodotUnityAdsBridge::initialize(String game_id, bool test_mode) {
    NSString *gameId = [NSString stringWithUTF8String:game_id.utf8().get_data()];
    [UnityAds initialize:gameId testMode:test_mode initializationDelegate:unityAds];
}

void GodotUnityAdsBridge::load_ad(String placement_id) {
    NSString *placement = [NSString stringWithUTF8String:placement_id.utf8().get_data()];
    [UnityAds load:placement loadDelegate:unityAds];
}

void GodotUnityAdsBridge::show_ad(String placement_id) {
    NSString *placement = [NSString stringWithUTF8String:placement_id.utf8().get_data()];
    UIViewController *rootController = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            rootController = windowScene.keyWindow.rootViewController;
            break;
        }
    }
    if (rootController == nil && UIApplication.sharedApplication.keyWindow != nil) {
        rootController = UIApplication.sharedApplication.keyWindow.rootViewController;
    }
    [UnityAds show:rootController placementId:placement showDelegate:unityAds];
}

void GodotUnityAdsBridge::load_banner(String placement_id, String position) {
    // Banner ads are not part of the rewarded flow; kept for interface parity.
    NSLog(@"GodotUnityAds: load_banner not supported on iOS rewarded flow");
}

void GodotUnityAdsBridge::show_banner() {
    NSLog(@"GodotUnityAds: show_banner not supported on iOS rewarded flow");
}

void GodotUnityAdsBridge::hide_banner() {
    NSLog(@"GodotUnityAds: hide_banner not supported on iOS rewarded flow");
}

void GodotUnityAdsBridge::destroy_banner() {
    NSLog(@"GodotUnityAds: destroy_banner not supported on iOS rewarded flow");
}

// --- signal emitters (always called on the main thread) --------------------
void GodotUnityAdsBridge::emit_initialized() {
    emit_signal("initialized");
}

void GodotUnityAdsBridge::emit_init_failed(String error, String message) {
    emit_signal("init_failed", error, message);
}

void GodotUnityAdsBridge::emit_ad_loaded(String placement_id) {
    emit_signal("ad_loaded", String(placement_id));
}

void GodotUnityAdsBridge::emit_ad_load_failed(String placement_id, String error, String message) {
    emit_signal("ad_load_failed", String(placement_id), error, message);
}

void GodotUnityAdsBridge::emit_ad_completed(String placement_id, String state) {
    emit_signal("ad_completed", String(placement_id), state);
}

void GodotUnityAdsBridge::emit_rewarded(String placement_id) {
    emit_signal("rewarded", String(placement_id));
}

void GodotUnityAdsBridge::emit_ad_show_failed(String placement_id, String error, String message) {
    emit_signal("ad_show_failed", String(placement_id), error, message);
}

// ---------------------------------------------------------------------------
// Method / signal registration
// ---------------------------------------------------------------------------
void GodotUnityAdsBridge::_bind_methods() {
    ADD_SIGNAL(MethodInfo("initialized"));
    ADD_SIGNAL(MethodInfo("init_failed", PropertyInfo(Variant::STRING, "error"), PropertyInfo(Variant::STRING, "message")));
    ADD_SIGNAL(MethodInfo("ad_loaded", PropertyInfo(Variant::STRING, "placement_id")));
    ADD_SIGNAL(MethodInfo("ad_load_failed", PropertyInfo(Variant::STRING, "placement_id"), PropertyInfo(Variant::STRING, "error"), PropertyInfo(Variant::STRING, "message")));
    ADD_SIGNAL(MethodInfo("ad_completed", PropertyInfo(Variant::STRING, "placement_id"), PropertyInfo(Variant::STRING, "state")));
    ADD_SIGNAL(MethodInfo("ad_show_failed", PropertyInfo(Variant::STRING, "placement_id"), PropertyInfo(Variant::STRING, "error"), PropertyInfo(Variant::STRING, "message")));
    ADD_SIGNAL(MethodInfo("rewarded", PropertyInfo(Variant::STRING, "placement_id")));

    ClassDB::bind_method(D_METHOD("is_available"), &GodotUnityAdsBridge::is_available);
    ClassDB::bind_method(D_METHOD("initialize"), &GodotUnityAdsBridge::initialize);
    ClassDB::bind_method(D_METHOD("load_ad"), &GodotUnityAdsBridge::load_ad);
    ClassDB::bind_method(D_METHOD("show_ad"), &GodotUnityAdsBridge::show_ad);
    ClassDB::bind_method(D_METHOD("load_banner"), &GodotUnityAdsBridge::load_banner);
    ClassDB::bind_method(D_METHOD("show_banner"), &GodotUnityAdsBridge::show_banner);
    ClassDB::bind_method(D_METHOD("hide_banner"), &GodotUnityAdsBridge::hide_banner);
    ClassDB::bind_method(D_METHOD("destroy_banner"), &GodotUnityAdsBridge::destroy_banner);
}

// ---------------------------------------------------------------------------
// Plugin registration entry points (referenced from the .gdip manifest)
// ---------------------------------------------------------------------------
GodotUnityAdsBridge *godot_unity_ads;

void register_godot_unity_ads_types() {
    godot_unity_ads = memnew(GodotUnityAdsBridge);
    Engine::get_singleton()->add_singleton(Engine::Singleton("GodotUnityAds", godot_unity_ads));
}

void unregister_godot_unity_ads_types() {
    if (godot_unity_ads) {
        memdelete(godot_unity_ads);
    }
}
