import 'local_resources_base.dart';
import 'local_resources_web.dart'
    if (dart.library.io) 'local_resources_io.dart'
    as platform;

export 'local_resources_base.dart';

LocalResourceStore createLocalResourceStore() =>
    platform.createLocalResourceStore();