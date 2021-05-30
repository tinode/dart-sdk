# Tinode Dart SDK  ![tests](https://github.com/tinode/dart-sdk/actions/workflows/dart.yml/badge.svg)

<img align="right" height="100" width="200" src="https://user-images.githubusercontent.com/32099630/112821615-28e00500-909c-11eb-831d-9e16fdcc86c0.png">

This SDK implements [Tinode](https://github.com/tinode/chat) client-side protocol for multi platform applications based on dart. This is not a standalone project. It can only be used in conjunction with the [Tinode server](https://github.com/tinode/chat). You can find released packages and versions on [pub page](https://pub.dev/packages/tinode).

## Installation

### Depend on it

Run this command for dart applications:

```
dart pub add tinode
```

Run this command for flutter applications:

```
flutter pub add tinode
```

### Import it

Now in your Dart code, you can use:

```
import 'package:tinode/tinode.dart';
```

## Getting support
* Read [server-side](https://github.com/tinode/chat/blob/master/docs/API.md) API documentation to know about packets.
* A complete documentation will be created soon.
* You can see a simple example in `./example` directory.
* For bugs and feature requests [open an issue](https://github.com/tinode/dart-sdk/issues/new)

## Platform support
* Servers
* Command-line scripts
* Flutter mobile apps
* Flutter desktop apps