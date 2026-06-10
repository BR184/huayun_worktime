typedef AsyncStep = Future<void> Function();
typedef MountedCheck = bool Function();

class StartupRefreshCoordinator {
  StartupRefreshCoordinator._();

  static Future<void> run({
    required AsyncStep initializeSession,
    required AsyncStep refreshDaily,
    required AsyncStep refreshMonthly,
    required MountedCheck isMounted,
  }) async {
    await initializeSession();
    if (!isMounted()) return;

    await refreshDaily();
    if (!isMounted()) return;

    await refreshMonthly();
  }
}
