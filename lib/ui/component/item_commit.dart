import 'dart:async';

import 'package:flutter/material.dart';
import 'package:GitSync/constant/strings.dart';
import 'package:GitSync/global.dart';
import 'package:sprintf/sprintf.dart';
import '../../../constant/colors.dart';
import '../../../constant/dimens.dart';
import '../../../src/rust/api/git_manager.dart' as GitManagerRs;
import 'package:timeago/timeago.dart' as timeago;

class ItemCommit extends StatefulWidget {
  const ItemCommit(this.commit, {super.key});

  final GitManagerRs.Commit commit;

  @override
  State<ItemCommit> createState() => _ItemCommit();
}

class _ItemCommit extends State<ItemCommit> {
  late Timer _timer;
  late String _relativeCommitDate;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) => _updateTime());
  }

  void _updateTime() {
    setState(() {
      _relativeCommitDate = timeago
          .format(DateTime.fromMillisecondsSinceEpoch(widget.commit.timestamp * 1000), locale: 'en')
          .replaceFirstMapped(RegExp(r'^[A-Z]'), (match) => match.group(0)!.toLowerCase());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: tertiaryDark, borderRadius: BorderRadius.all(cornerRadiusSM)),
      padding: EdgeInsets.all(spaceSM),
      margin: EdgeInsets.only(top: spaceSM),
      width: double.infinity,
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(widget.commit.commitMessage, style: TextStyle(color: primaryLight, fontSize: textMD, overflow: TextOverflow.ellipsis)),
                  Text(
                    "${demo ? "ViscousTests" : widget.commit.author} ${t.committed} $_relativeCommitDate",
                    style: TextStyle(color: secondaryLight, fontSize: textSM, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            SizedBox(width: spaceXS),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(color: secondaryLight, borderRadius: BorderRadius.all(cornerRadiusXS)),
                  padding: EdgeInsets.symmetric(horizontal: spaceXS, vertical: spaceXXXS),
                  child: Text(
                    (widget.commit.reference).substring(0, 7).toUpperCase(),
                    style: TextStyle(color: tertiaryDark, fontSize: textXS, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: spaceXXXS),
                Row(
                  children: [
                    Text(
                      sprintf(t.additions, [widget.commit.additions]),
                      style: TextStyle(color: tertiaryPositive, fontSize: textXS, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(width: spaceSM),
                    Text(
                      sprintf(t.deletions, [widget.commit.deletions]),
                      style: TextStyle(color: tertiaryNegative, fontSize: textXS, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
