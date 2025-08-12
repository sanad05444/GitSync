import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:GitSync/api/logger.dart';
import 'package:GitSync/constant/strings.dart';
import 'package:GitSync/src/rust/api/git_manager.dart' as GitManagerRs;
import 'package:ios_document_picker/ios_document_picker.dart';
import 'package:ios_document_picker/types.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:GitSync/global.dart';
import '../constant/colors.dart';
import '../constant/dimens.dart';

const int mergeConflictNotificationId = 1758;
Map<String, Timer> debounceTimers = {};
Map<String, VoidCallback> _callbacks = {};

Future<void> initAsync(Future<void> Function() fn) async {
  await Future.delayed(Duration.zero, fn);
}

Future<bool> requestStoragePerm([bool request = true]) async {
  Future<void> gitManagerInit() async =>
      await GitManagerRs.init(homepath: Platform.isAndroid ? (await getApplicationDocumentsDirectory()).path : null);

  if (Platform.isIOS) {
    await gitManagerInit();
    return true;
  }

  AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
  if (androidInfo.version.sdkInt <= 29) {
    var storageRequest = Permission.storage;
    if (await (request ? storageRequest.request().isGranted : storageRequest.isGranted)) {
      await gitManagerInit();
      return true;
    }
    return false;
  }

  var storageRequest = Permission.manageExternalStorage;
  if (await (request ? storageRequest.request().isGranted : storageRequest.isGranted)) {
    await gitManagerInit();
    return true;
  }
  return false;
}

Widget? getBackButton(BuildContext context, Function() onPressed) =>
    IconButton(onPressed: onPressed, icon: FaIcon(FontAwesomeIcons.arrowLeft, color: primaryLight, size: textLG, semanticLabel: t.backLabel));

void debounce(String index, int milliseconds, VoidCallback callback) {
  debounceTimers[index]?.cancel();
  _callbacks[index] = callback;
  debounceTimers[index] = Timer(Duration(milliseconds: milliseconds), callback);
}

void cancelDebounce(String index, [bool run = false]) {
  debounceTimers[index]?.cancel();
  if (run) {
    _callbacks[index]!();
  }
}

Future<void> sendMergeConflictNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    gitSyncNotifyChannelId,
    gitSyncNotifyChannelName,
    icon: gitSyncIconRes,
    importance: Importance.high,
    priority: Priority.high,
  );
  const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

  await Logger.notificationsPlugin.show(
    mergeConflictNotificationId,
    mergeConflictNotificationTitle,
    mergeConflictNotificationBody,
    notificationDetails,
  );
}

Future<bool> hasNetworkConnection() async {
  return (await Connectivity().checkConnectivity())[0] != ConnectivityResult.none;
}

Future<T?> returnWhenOffline<T>(Future<T> Function() callback) async {
  return (await Connectivity().checkConnectivity())[0] == ConnectivityResult.none ? callback() : null;
}

Future<String?> pickDirectory() async {
  if (Platform.isAndroid) {
    final path = await FilePicker.platform.getDirectoryPath();
    return path;
  }

  final iosDocumentPickerPlugin = IosDocumentPicker();
  var result = await iosDocumentPickerPlugin.pick(IosDocumentPickerType.directory, multiple: false);
  if (result == null) {
    return null;
  }

  return result[0].bookmark;
}

Future<T?> useDirectory<T>(String bookmarkPath, Future<void> Function(String) setBookmarkPath, Future<T?> Function(String path) useAccess) async {
  Future<T?> preUseAccess(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return null;
    }

    return await useAccess(path);
  }

  if (Platform.isAndroid) return await preUseAccess(bookmarkPath);

  if (bookmarkPath.isEmpty) return null;

  final iosDocumentPickerPlugin = IosDocumentPicker();
  String? path;

  try {
    final bookmarkAndPath = await iosDocumentPickerPlugin.resolveBookmark(bookmarkPath, isDirectory: true);
    if (bookmarkAndPath == null) return null;
    await setBookmarkPath(bookmarkAndPath.$1);
    path = bookmarkAndPath.$2;
  } catch (e) {
    print(e);
    return null;
  }

  if (path.isEmpty) {
    return null;
  }

  final hasAccess = await iosDocumentPickerPlugin.startAccessing(path);
  if (!hasAccess) {
    Logger.logError(LogType.SelectDirectory, "No folder access", StackTrace.fromString(""));
    return null;
  }

  final result = await preUseAccess(path);

  debounce("$iosFolderAccessDebounceReference-$path", 60000, () async => await iosDocumentPickerPlugin.stopAccessing(path!));

  return result;
}

Future<String> encryptMap(Map<String, dynamic> data, String password) async {
  final salt = _randomBytes(16);
  final key = await _deriveKey(password, salt);
  final nonce = _randomBytes(12);
  final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm));
  final json = jsonEncode(data);
  final encrypted = encrypter.encrypt(json, iv: encrypt.IV(Uint8List.fromList(nonce)));

  final result = <int>[...salt, ...nonce, ...encrypted.bytes];
  return base64Encode(result);
}

Future<Map<String, dynamic>> decryptMap(String encryptedBase64, String password) async {
  final data = base64Decode(encryptedBase64);
  final salt = data.sublist(0, 16);
  final nonce = data.sublist(16, 28);
  final ciphertext = data.sublist(28);
  final key = await _deriveKey(password, salt);
  final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm));
  final decrypted = encrypter.decrypt(encrypt.Encrypted(ciphertext), iv: encrypt.IV(nonce));
  return jsonDecode(decrypted);
}

Future<Uint8List> _deriveKey(String password, List<int> salt, {int iterations = 100000, int keyLength = 32}) async {
  final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: keyLength * 8);
  final secretKey = await pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  final keyBytes = await secretKey.extractBytes();
  return Uint8List.fromList(keyBytes);
}

List<int> _randomBytes(int length) {
  final rand = Random.secure();
  return List<int>.generate(length, (_) => rand.nextInt(256));
}
