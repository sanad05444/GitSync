import 'package:flutter/material.dart';
import 'package:GitSync/global.dart';
import './verify_gh_sponsor.dart' as VerifyGHSponsorDialog;

Future<void> showDialog(BuildContext context, VoidCallback purchaseCallback) async {
  await VerifyGHSponsorDialog.showDialog(context);
  if (premiumManager.hasPremiumNotifier.value == true) {
    purchaseCallback();
  }
}
