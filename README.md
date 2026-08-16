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

The Android package is `com.josh.suppup`. Version 1.0.1 is the current tested
release.

## Important public-launch note

Ratings and favorites are currently stored only on the phone. The app includes
a public privacy policy and resilient light-use OpenStreetMap searches. A larger
public launch will still need a scalable map-data plan; community Overpass
services are best-effort and are not a guaranteed production backend.

## Google Play release

Play Store copy, data-safety notes, and graphics live in `play_store/`. Release
signing reads the ignored `android/key.properties` file and never checks the
upload key or its password into Git.

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
