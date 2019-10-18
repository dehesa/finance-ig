#include "Framework.h"

//struct IGInfo const* const _Nonnull IGBundle = &info;
struct IGFrameworkInfo IGFramework = {
    .name = IG_BUNDLE_NAME,
    .identifier = IG_BUNDLE_ID,
    .version = IG_BUNDLE_VERSION,
    .build = IG_BUNDLE_BUILD
};
