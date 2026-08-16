# Suppup

Suppup helps dog owners discover leash-friendly walking paths, highly rated dog
parks, and nearby places to pick up treats.

## First working version

- Uses the phone's current location.
- Finds mapped paths, dog parks, pet shops, and dog-friendly treat stops nearby.
- Shows selectable map pins and distance-sorted results.
- Ranks dog parks by Suppup rating, then distance.
- Lets people save favorites and rate a spot on their phone.
- Opens walking directions in the phone's maps app.
- Uses OpenStreetMap data and does not require a paid API key.
- Clearly labels preview examples when live map data or location is unavailable.

The Android package is `com.josh.suppup`. Version 1.0.0 is the first prototype.

## Important public-launch note

Ratings are currently stored on the phone. A public release will need a shared
backend, moderation, abuse protection, privacy documentation, and a scalable map
data strategy. The public Overpass service is useful for development and light
testing; a production app should not depend on a community endpoint without a
capacity plan.

## Checks

```text
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is created at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Map and place data © OpenStreetMap contributors.
