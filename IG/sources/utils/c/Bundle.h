#ifndef IG_Bundle_h
#define IG_Bundle_h

struct IGBundleInfo {
    /// The framework's given name.
    char const* const _Nonnull name;
    /// The framework's bundle identifier
    char const* const _Nonnull identifier;
    /// The framework's version (major, minor, bug)
    char const* const _Nonnull version;
    /// The framework's build number.
    unsigned short build;
};

extern struct IGBundleInfo IGBundle;

#endif
