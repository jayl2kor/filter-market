# filterMarket

iOS-native camera filter marketplace. Current implementation status: Phase 0 bootstrap and Camera + Metal preview PoC foundation.

## Open

```bash
xcodegen generate
open filterMarket.xcodeproj
```

## Build

```bash
./scripts/build.sh
```

Build products are written to `.build/DerivedData` by default. Override with `DERIVED_DATA_PATH=/path/to/DerivedData`.

## Test

```bash
./scripts/test.sh
```

Override simulator selection with `IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=26.3.1'`.

## Metal Toolchain

```bash
./scripts/metal-toolchain.sh
```

## Docs

- [Project docs](./docs/README.md)
- [Implementation plan](./docs/IMPLEMENTATION_PLAN.md)
- [Implementation status](./docs/IMPLEMENTATION_STATUS.md)
