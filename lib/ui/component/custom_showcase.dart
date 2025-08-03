import 'package:GitSync/constant/colors.dart';
import 'package:GitSync/constant/dimens.dart';
import 'package:GitSync/constant/strings.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomShowcase extends StatelessWidget {
  const CustomShowcase({
    super.key,
    required this.globalKey,
    required this.child,
    required this.description,
    this.customTooltipActions,
    this.cornerRadius,
    this.targetPadding,
    this.first = false,
    this.last = false,
  });

  final GlobalKey globalKey;
  final Widget child;
  final String description;
  final List<TooltipActionButton>? customTooltipActions;
  final Radius? cornerRadius;
  final EdgeInsets? targetPadding;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) => Showcase(
    key: globalKey,
    targetBorderRadius: cornerRadius == null ? null : BorderRadius.all(cornerRadius!),
    description: description,
    descTextStyle: TextStyle(fontSize: textMD, fontWeight: FontWeight.w500, color: primaryDark),
    targetPadding: targetPadding ?? EdgeInsets.all(spaceSM),
    tooltipActions: [
      ...customTooltipActions ?? [],
      ...!first
          ? [
            TooltipActionButton(
              type: TooltipDefaultActionType.previous,
              backgroundColor: primaryLight,
              textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: textSM, color: primaryDark),
              name: "Previous".toUpperCase(),
            ),
          ]
          : [],
      ...!last
          ? [
            TooltipActionButton(
              type: TooltipDefaultActionType.next,
              backgroundColor: primaryLight,
              textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: textSM, color: primaryDark),
              name: "Next".toUpperCase(),
            ),
          ]
          : [
            TooltipActionButton(
              type: TooltipDefaultActionType.next,
              backgroundColor: primaryLight,
              textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: textSM, color: primaryDark),
              name: "Finish".toUpperCase(),
            ),
          ],
    ],
    tooltipBackgroundColor: tertiaryInfo,
    textColor: secondaryDark,
    child: child,
  );
}
