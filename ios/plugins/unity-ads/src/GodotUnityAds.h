// GodotUnityAds.h
//
// Objective-C++ bridge exposing the Unity Ads iOS SDK to Godot as the
// `GodotUnityAds` native singleton. Mirrors the interface of the Android
// `GodotUnityAds` plugin so one GDScript abstraction (UnityAds autoload)
// works on both platforms.
//
// Signals (match the Android plugin):
//   initialized
//   init_failed(error: String, message: String)
//   ad_loaded(placement_id: String)
//   ad_load_failed(placement_id: String, error: String, message: String)
//   ad_completed(placement_id: String, state: String)   state: "COMPLETED" | "SKIPPED" | ...
//   ad_show_failed(placement_id: String, error: String, message: String)
//   rewarded(placement_id: String)

#ifndef GODOT_UNITY_ADS_H
#define GODOT_UNITY_ADS_H

#import <Foundation/Foundation.h>
#import <UnityAds/UnityAds.h>
#import <UnityAds/UnityAds-Swift.h>
#include "core/object/class_db.h"

@interface GodotUnityAds : NSObject <UnityAdsInitializationDelegate, UnityAdsLoadDelegate, UnityAdsShowDelegate>
@end

class GodotUnityAdsBridge : public Object {
    GDCLASS(GodotUnityAdsBridge, Object);

    static GodotUnityAdsBridge *instance;
    static void _bind_methods();

    GodotUnityAds *unityAds;

public:
    bool is_available();
    void initialize(String game_id, bool test_mode);
    void load_ad(String placement_id);
    void show_ad(String placement_id);
    void load_banner(String placement_id, String position);
    void show_banner();
    void hide_banner();
    void destroy_banner();

    void emit_initialized();
    void emit_init_failed(String error, String message);
    void emit_ad_loaded(String placement_id);
    void emit_ad_load_failed(String placement_id, String error, String message);
    void emit_ad_completed(String placement_id, String state);
    void emit_rewarded(String placement_id);
    void emit_ad_show_failed(String placement_id, String error, String message);

    static GodotUnityAdsBridge *get_singleton();

    GodotUnityAdsBridge();
    ~GodotUnityAdsBridge();
};

void register_godot_unity_ads_types();
void unregister_godot_unity_ads_types();

#endif /* GODOT_UNITY_ADS_H */
