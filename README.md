# prayer-cast

Tursina Labs — offline-first prayer times app. Casts the adzan to a home
Google Cast speaker when the user is actually home, exactly once across
family devices.

See [ADZAN_HOME_DELIVERY_SPEC.md](./ADZAN_HOME_DELIVERY_SPEC.md) for the
`home_delivery` layer design (presence → coordination → cast).

## Develop

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
```
