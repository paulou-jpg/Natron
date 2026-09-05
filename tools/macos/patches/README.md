# OpenFX plug-in patches

Patches required to build working `IO.ofx` (openfx-io) plug-ins on macOS against
current Homebrew dependencies. Apply them to a checkout of
[openfx-io](https://github.com/NatronGitHub/openfx-io) before building.

They are kept here because they are needed to produce a usable Natron on this
platform, but they belong upstream: 0001 is an openfx bug, 0002-0004 are
openfx-io bugs. `libs/OpenFX` in this repository is the *same* library as 0001
patches and carries the identical defect.

| Patch | Repository | Fixes |
| --- | --- | --- |
| 0001 | `openfx` (submodule of openfx-io) | Crash: `resetOptions()` passes an empty vector to `propSetStringN` |
| 0002 | `openfx-io` | ACES configs: `rec709`/`sRGB` defaults could not be resolved |
| 0003 | `openfx-io` | Build against the SeExpr2 header layout |
| 0004 | `openfx-io` | Drop the SeExpr plug-in, which upstream never finished porting |

## 0001 — `resetOptions()` crash (the important one)

`ChoiceParam::resetOptions()` called with no arguments reaches

```cpp
_paramProps.propSetStringN(kOfxParamPropChoiceOption, newEntries);   // newEntries is empty
```

and `propSetStringN` does `&data[0]` on an empty vector. That is undefined
behaviour; under libc++ it reads address 0 and the **host** segfaults:

```
OFX::PropertySet::propSetStringN(char const*, vector<string> const&)
OFX::IO::buildChoiceMenu<OFX::ChoiceParam>(...)      <- first statement is choice->resetOptions()
OFX::IO::GenericOCIO::GenericOCIO(OFX::ImageEffect*)
WriteOIIOPluginFactory::createInstance(...)
```

The guard above it already intends to handle this — its comment reads
"Invalid parameters **or empty newEntries**, reset the property" — but the
condition never tests `newEntries.empty()`. The patch adds that test (at both
sites) and makes `propSetStringN` pass `NULL` rather than `&data[0]` when the
vector is empty.

Without this, creating any `WriteOIIO` node crashes Natron. Excluding
`WriteOIIO` is **not** a workaround: `WriteEXR`, `WritePNG` and the other
format-specific writers are all marked
`desc.setIsDeprecated(true) // superseeded by WriteOIIO`, and Natron omits
deprecated plug-ins from its encoder table, so dropping `WriteOIIO` leaves no
encoder for any format.

## 0002 — ACES colorspace defaults

`colorSpaceName()` maps a generic default such as `rec709` onto whatever the
loaded config actually calls it, via a list of per-config aliases. The list
stopped at ACES 1.0.0, so with an ACES 1.0.3/1.1/1.2 config nothing matched and
the unresolvable literal was returned, failing every render with

```
Color space 'rec709' could not be found.
```

The patch adds the `Output - Rec.709` / `Output - sRGB` names used from ACES
1.0.3 onwards, and — when a config names none of the variants — falls back to
the roles the config does define rather than a name it cannot resolve. A
display-referred default maps to `color_picking`, which ACES configs define as
a displayable space (`Output - sRGB` in ACES 1.2). This follows the way Nuke
derives its defaults from a config's roles.

## Building

```sh
git clone --recursive https://github.com/NatronGitHub/openfx-io.git
cd openfx-io
git apply .../0002-*.patch .../0003-*.patch .../0004-*.patch
git -C openfx apply .../0001-*.patch

# MacPorts' pkg-config must not win here: it silently supplies FFmpeg 4.x
export PKG_CONFIG_PATH="$(for p in openexr imath opencolorio openimageio ffmpeg \
    libraw webp libtiff openjpeg libpng; do printf '%s/lib/pkgconfig:' "$(brew --prefix $p)"; done)"
export PATH="/usr/local/bin:$PATH"

make -j8 CONFIG=release BITS=64 \
  CXXFLAGS_EXTRA="-std=c++17 -I$(brew --prefix fmt)/include -DSEEXPR_NEW_LAYOUT -I$(brew --prefix seexpr)/include" \
  SEEXPR_LINKFLAGS="-L$(brew --prefix seexpr)/lib -lSeExpr2 -Wl,-rpath,$(brew --prefix seexpr)/lib"
```

OpenImageIO 3 requires C++17 and `fmt`, hence `CXXFLAGS_EXTRA`.

Then install into a bundle with `tools/macos/install-ofx-plugins.sh`.

**Note on rebuilding:** these Makefiles do not track header dependencies, and
removing an object from `PLUGINOBJECTS` does not relink, so delete
`IO/Darwin-64-release` when changing either. `nm | grep` is not a reliable check
for what was linked in — plug-in classes live in anonymous namespaces and are
stripped from a release build's symbol table; use
`strings IO.ofx | grep fr.inria.openfx.` instead.
