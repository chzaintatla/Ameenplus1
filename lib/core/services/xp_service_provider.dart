import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'xp_service.dart';

final xpServiceProvider = Provider<XPService>((ref) {
  return XPService();
});

